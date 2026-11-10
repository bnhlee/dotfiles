-- While text is selected in charwise visual mode, highlight the other places
-- the same text appears on screen, in every window of the tab page. Only
-- one-line selections of 2+ characters that aren't just whitespace, matched
-- exactly (case-sensitive, no regex). Only the visible lines are searched, so
-- it's cheap on big files.
local M = {}

local ns = vim.api.nvim_create_namespace("visual_match")
-- Buffers with highlights in them (as keys), so leaving visual mode clears
-- just those
local marked = {}

-- Same look as search matches, which stand apart from the selection (unlike
-- LspReferenceText, which catppuccin draws the same as Visual); override
-- VisualMatch in a colorscheme to change it
vim.api.nvim_set_hl(0, "VisualMatch", { link = "Search", default = true })

local function clear()
    for buf in pairs(marked) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
    end
    marked = {}
end

-- The visible rows (0-based, as keys) of each buffer to search, by buffer.
-- Rows are merged per buffer, so a buffer in two splits with overlapping
-- views is searched once per line. Besides the current window, only regular
-- file windows count: no floats (telescope, hovers), terminals, oil, help or
-- quickfix.
local function visible_rows()
    local cur = vim.api.nvim_get_current_win()
    local rows = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local regular = vim.api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype == ""
        if win == cur or regular then
            rows[buf] = rows[buf] or {}
            for row = vim.fn.line("w0", win) - 1, vim.fn.line("w$", win) - 1 do
                rows[buf][row] = true
            end
        end
    end
    return rows
end

-- The selected text, and its start (0-based row and byte column), if the
-- selection is worth matching
local function selection()
    if vim.fn.mode() ~= "v" then
        return
    end
    local from, to = vim.fn.getpos("v"), vim.fn.getpos(".")
    if from[2] ~= to[2] then
        return
    end
    local text = vim.fn.getregion(from, to, { type = "v" })[1]
    if not text or #text < 2 or not text:find("%S") then
        return
    end
    return text, from[2] - 1, math.min(from[3], to[3]) - 1
end

function M.update()
    clear()
    local text, sel_row, sel_col = selection()
    if not text then
        return
    end
    local sel_buf = vim.api.nvim_get_current_buf()
    for buf, rows in pairs(visible_rows()) do
        for row in pairs(rows) do
            local line, init = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or "", 1
            while true do
                local s, e = line:find(text, init, true)
                if not s then
                    break
                end
                -- Leave the selection itself to the Visual highlight, including
                -- matches that overlap it (e.g. in a run of repeated characters)
                if buf ~= sel_buf or row ~= sel_row or e <= sel_col or s - 1 >= sel_col + #text then
                    vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, { end_col = e, hl_group = "VisualMatch" })
                    marked[buf] = true
                end
                init = e + 1
            end
        end
    end
end

local group = vim.api.nvim_create_augroup("visual_match", { clear = true })
-- Entering or leaving visual mode, extending the selection, scrolling
vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved", "WinScrolled" }, {
    group = group,
    callback = function()
        -- CursorMoved fires on every move in normal mode too; skip the work
        -- unless there's a selection or something to clear
        if next(marked) or vim.fn.mode() == "v" then
            M.update()
        end
    end,
})

return M
