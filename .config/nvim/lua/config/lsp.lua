-- Server configs live in ~/.config/nvim/lsp/<name>.lua
vim.lsp.enable({ "gopls" })

vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = { border = "rounded" },
})

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

-- Built-in defaults already cover most actions: K hover, grn rename,
-- gra code action, grr references, gri implementation, grt type definition,
-- gO document symbols, [d / ]d diagnostics, <C-w>d diagnostic float.
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
        map("n", "<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
        end, "Toggle inlay hints")

        if client:supports_method("textDocument/formatting") then
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
