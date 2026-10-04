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

-- FileType rather than BufReadPost: on open, the filetype isn't known yet
vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("lint", { clear = true }),
    callback = function(args)
        -- golangci-lint has to run from inside the module
        lint.try_lint(nil, { cwd = vim.fs.root(args.buf, { "go.work", "go.mod" }) })
    end,
})
