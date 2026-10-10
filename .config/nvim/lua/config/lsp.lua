-- Server configs live in ~/.config/nvim/lsp/<name>.lua. Only the installed
-- ones are enabled, so a missing server doesn't error on every file open.
for _, name in ipairs({ "gopls", "bashls", "lua_ls", "ts_ls", "powershell_es" }) do
    local config = vim.lsp.config[name]
    if vim.fn.executable(config.cmd[1]) == 1 and (not config.bundle or vim.uv.fs_stat(config.bundle)) then
        vim.lsp.enable(name)
    end
end

-- Tell servers about files changed on disk outside nvim (git checkout, a
-- rename in the shell), so e.g. gopls sees renamed or new files. Off by default
-- on Linux because the fallback watcher is too limited; inotifywait (from
-- inotify-tools) makes it reliable.
if vim.fn.executable("inotifywait") == 1 then
    vim.lsp.config("*", {
        capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
    })
end

-- Servers whose formatting runs on save. The others format with gq, so their
-- formatters don't rewrite files that follow a different style.
local format_on_save = { gopls = true }

vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = { border = "rounded" },
    -- With 'nowrap', virtual text past the window edge is cut off, so [d / ]d
    -- also open the float, which wraps the full message
    jump = {
        on_jump = function(diagnostic, bufnr)
            if diagnostic then
                vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
            end
        end,
    },
})

-- Hover and diagnostic floats are placed relative to the cursor's screen
-- position, so they stay put when the view scrolls (<C-e>, <C-y>, zz). Anchor
-- them to the buffer position instead, so they move with the text.
local make_floating_popup_options = vim.lsp.util.make_floating_popup_options
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.util.make_floating_popup_options = function(width, height, opts)
    local options = make_floating_popup_options(width, height, opts)
    if options.relative == "cursor" then
        local cursor = vim.api.nvim_win_get_cursor(0)
        options.relative = "win"
        options.win = vim.api.nvim_get_current_win()
        options.bufpos = { cursor[1] - 1, cursor[2] }
    end
    return options
end

-- When scrolling pushes an anchored float into the window edge, move it to the
-- other side of its line, or close it if it fits on neither side
local open_floating_preview = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
    local bufnr, winid = open_floating_preview(contents, syntax, opts)
    local config = vim.api.nvim_win_get_config(winid)
    -- A float that is focused or updated comes back again; it's already watched
    if config.bufpos and not vim.w[winid].anchored_float then
        vim.w[winid].anchored_float = true
        local border = type(config.border) == "table" and config.border[1] ~= "" and 2 or 0
        vim.api.nvim_create_autocmd("WinScrolled", {
            callback = function()
                if not vim.api.nvim_win_is_valid(winid) or not vim.api.nvim_win_is_valid(config.win) then
                    return true
                end
                local top = vim.api.nvim_win_call(config.win, function()
                    return vim.fn.line("w0")
                end)
                local line = config.bufpos[1]
                if line + 1 < top then
                    return -- the cursor moved with it, so CursorMoved closes the float
                end
                -- screen rows above the line, and the float's height with border
                local above = line + 1 > top
                        and vim.api.nvim_win_text_height(config.win, { start_row = top - 1, end_row = line - 1 }).all
                    or 0
                local below = vim.api.nvim_win_get_height(config.win) - above - 1
                local height = vim.api.nvim_win_get_height(winid) + border
                local fits_above, fits_below = height <= above, height <= below

                -- Fresh config: an updated float (signature help's <C-s>) may
                -- have a new title and height since it opened
                local current = vim.api.nvim_win_get_config(winid)
                local side = current.anchor:sub(1, 1)
                if side == "S" and not fits_above and fits_below then
                    side = "N"
                elseif side == "N" and not fits_below and fits_above then
                    side = "S"
                elseif not (fits_above or fits_below) then
                    vim.api.nvim_win_close(winid, true)
                    return true
                end
                if side ~= current.anchor:sub(1, 1) then
                    current.anchor = side .. current.anchor:sub(2)
                    current.row = side == "N" and 1 or 0
                    vim.api.nvim_win_set_config(winid, current)
                end
            end,
        })
    end
    return bufnr, winid
end

-- gopls only fixes imports through a code action, so run it before formatting
local function organize_imports(client, bufnr)
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { "source.organizeImports" }, diagnostics = {} }
    local res = client:request_sync("textDocument/codeAction", params, 1000, bufnr)
    for _, action in ipairs(res and res.result or {}) do
        if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
        end
    end
end

-- Jump to the definition, or list references when already on it (like an
-- IDE's ctrl-click). The jump itself goes through the built-in definition, so
-- <C-t> still returns.
local function definition_or_references()
    local filename = vim.api.nvim_buf_get_name(0)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    col = col + 1
    vim.lsp.buf.definition({
        on_list = function(list)
            for _, item in ipairs(list.items) do
                local after_start = row > item.lnum or (row == item.lnum and col >= item.col)
                local before_end = row < item.end_lnum or (row == item.end_lnum and col < item.end_col)
                if item.filename == filename and after_start and before_end then
                    require("telescope.builtin").lsp_references()
                    return
                end
            end
            vim.lsp.buf.definition()
        end,
    })
end

-- Built-in defaults already cover most actions: K hover, grn rename,
-- gra code action, gri implementation, grt type definition, gO document
-- symbols, [d / ]d diagnostics, <C-w>d diagnostic float.
-- Completion and signature help come from blink.cmp (plugins/blink.lua).
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local bufnr = args.buf
        local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "gd", vim.lsp.buf.definition, "Go to definition")
        map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
        -- References in a Telescope picker instead of the quickfix split;
        -- <C-q> in the picker still sends them to quickfix
        map("n", "grr", function()
            require("telescope.builtin").lsp_references()
        end, "Find references")
        map("n", "<C-]>", definition_or_references, "Definition, or references if on it")
        map("n", "<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
        end, "Toggle inlay hints")

        if format_on_save[client.name] and client:supports_method("textDocument/formatting") then
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = vim.api.nvim_create_augroup("lsp_format_" .. bufnr, { clear = true }),
                buffer = bufnr,
                callback = function()
                    if client.name == "gopls" then
                        organize_imports(client, bufnr)
                    end
                    vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 1000 })
                end,
            })
        end
    end,
})
