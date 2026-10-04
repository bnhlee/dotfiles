-- Run `go test` / `go run` in a terminal split at the bottom.
-- The split is reused between runs; q closes it.
local M = {}

local last
local term_buf

local function test_name_at_cursor()
    -- Parsing is async, so make sure the tree is up to date before looking at it
    local parser = vim.treesitter.get_parser(0, "go", { error = false })
    if parser then
        parser:parse()
    end
    local ok, node = pcall(vim.treesitter.get_node)
    while ok and node do
        if node:type() == "function_declaration" then
            local name = vim.treesitter.get_node_text(node:field("name")[1], 0)
            if name:match("^Test") or name:match("^Benchmark") or name:match("^Fuzz") or name:match("^Example") then
                return name
            end
        end
        node = node:parent()
    end
end

local function run(cmd, cwd)
    last = { cmd = cmd, cwd = cwd }
    local src_win = vim.api.nvim_get_current_win()
    if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
        vim.api.nvim_buf_delete(term_buf, { force = true })
    end
    vim.cmd("botright 15new")
    term_buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart(cmd, { term = true, cwd = cwd })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = term_buf, desc = "Close output" })
    vim.api.nvim_set_current_win(src_win)
end

local function pkg_dir()
    return vim.fn.expand("%:p:h")
end

local function module_root()
    return vim.fs.root(0, { "go.work", "go.mod" }) or vim.fn.getcwd()
end

function M.nearest()
    local name = test_name_at_cursor()
    if not name then
        vim.notify("No test function under cursor", vim.log.levels.WARN)
        return
    end
    local pattern = "^" .. name .. "$"
    if name:match("^Benchmark") then
        run({ "go", "test", "-run", "^$", "-bench", pattern, "." }, pkg_dir())
    else
        run({ "go", "test", "-v", "-count=1", "-run", pattern, "." }, pkg_dir())
    end
end

function M.package()
    run({ "go", "test", "-count=1", "." }, pkg_dir())
end

function M.all()
    run({ "go", "test", "-count=1", "./..." }, module_root())
end

function M.go_run()
    run({ "go", "run", "." }, pkg_dir())
end

function M.last()
    if not last then
        vim.notify("Nothing run yet", vim.log.levels.WARN)
        return
    end
    run(last.cmd, last.cwd)
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function(args)
        local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
        end
        map("<leader>rt", M.nearest, "Run nearest test")
        map("<leader>rp", M.package, "Run package tests")
        map("<leader>ra", M.all, "Run all tests in module")
        map("<leader>rr", M.go_run, "go run package")
        map("<leader>rl", M.last, "Rerun last")
    end,
})

return M
