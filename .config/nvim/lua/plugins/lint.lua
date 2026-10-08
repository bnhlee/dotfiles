-- golangci-lint on open and save, for linters gopls doesn't have (errcheck,
-- ineffassign, ...). It reads files from disk, so it can't lint unsaved
-- changes. Results show up as normal diagnostics once the run finishes.
local lint = require("lint")

-- Optional: skip it on machines where it isn't installed
if vim.fn.executable("golangci-lint") == 1 then
    lint.linters_by_ft.go = { "golangcilint" }
    -- Always lint the file's whole package. nvim-lint falls back to linting
    -- the file alone when nvim was started outside the module, which reports
    -- anything defined in sibling files as undefined.
    local args = lint.linters.golangcilint.args
    args[#args] = function()
        return vim.fn.expand("%:p:h")
    end
    -- gopls already runs these live as you type; skip them here to avoid
    -- duplicate warnings. `golangci-lint run` outside nvim still includes them.
    table.insert(args, #args, "--disable=govet,staticcheck")
end

local function lint_buf(bufnr)
    -- golangci-lint has to run from inside the module
    lint.try_lint(nil, { cwd = vim.fs.root(bufnr, { "go.work", "go.mod" }) })
end

-- FileType rather than BufReadPost: on open, the filetype isn't known yet
vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("lint", { clear = true }),
    callback = function(args)
        lint_buf(args.buf)
    end,
})

-- Lint only reruns on the buffer being opened or saved, so fixing one file
-- leaves stale warnings in the others. This clears every diagnostic, restarts
-- the LSP servers and re-lints all open files.
vim.keymap.set("n", "<leader>lr", function()
    vim.diagnostic.reset()
    -- Name every active client: a bare :lsp restart only restarts the ones
    -- attached to the current buffer, leaving the other buffers cleared
    local names = {}
    for _, client in ipairs(vim.lsp.get_clients()) do
        names[client.name] = true
    end
    if next(names) then
        vim.cmd("lsp restart " .. table.concat(vim.tbl_keys(names), " "))
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
            -- try_lint works on the current buffer
            vim.api.nvim_buf_call(bufnr, function()
                lint_buf(bufnr)
            end)
        end
    end
end, { desc = "Refresh diagnostics (restart LSP, re-lint)" })
