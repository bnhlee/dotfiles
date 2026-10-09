-- End-to-end check of config/lsp_sync.lua with the real config and gopls.
-- Slow (about 20s) and needs go and gopls, so it's run by hand after
-- changing the sync, not routinely; tests/lsp_sync.lua covers the logic.
--
-- Replays a bug the sync had: with changes stashed, jump to a definition
-- (opening its file in a buffer), go back, then pop the stash. The opened
-- buffer must pick up the popped version, so go-to-definition still works.
--
-- Run: nvim --headless -c "luafile ~/.config/nvim/tests/manual_gopls.lua"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_AUTHOR_NAME, vim.env.GIT_AUTHOR_EMAIL = "test", "test@example.com"
vim.env.GIT_COMMITTER_NAME, vim.env.GIT_COMMITTER_EMAIL = "test", "test@example.com"

local root = vim.fn.tempname()
local failures = 0

local function git(...)
    local res = vim.system({ "git", ... }, { cwd = root }):wait()
    assert(res.code == 0, ("git %s: %s"):format(table.concat({ ... }, " "), res.stderr))
end

local function write(path, text)
    vim.fn.writefile(vim.split(text, "\n"), vim.fs.joinpath(root, path))
end

-- Poll until fn() returns true, for up to timeout ms
local function eventually(fn, timeout)
    local deadline = vim.uv.now() + (timeout or 20000)
    while vim.uv.now() < deadline do
        if fn() then
            return true
        end
        vim.wait(300)
    end
    return false
end

local function check(name, ok)
    io.write((ok and "ok   " or "FAIL ") .. name .. "\n")
    if not ok then
        failures = failures + 1
    end
end

local main

-- Where gopls says the helper called on main.go's line 3 is defined
local function definition()
    vim.api.nvim_set_current_buf(main)
    local line = vim.api.nvim_buf_get_lines(main, 2, 3, false)[1]
    vim.api.nvim_win_set_cursor(0, { 3, (line:find("helper")) })
    local params = vim.lsp.util.make_position_params(0, "utf-16")
    local res = vim.lsp.buf_request_sync(main, "textDocument/definition", params, 5000) or {}
    for _, r in pairs(res) do
        for _, loc in ipairs(r.result or {}) do
            return vim.fs.basename(vim.uri_to_fname(loc.uri)) .. ":" .. loc.range.start.line + 1
        end
    end
end

local function works()
    return definition() == "util.go:3"
        and #vim.diagnostic.get(main, { severity = vim.diagnostic.severity.ERROR }) == 0
end

local function run()
    -- Committed: helper(). Uncommitted: renamed to helperRenamed() in both files.
    vim.fn.mkdir(root, "p")
    git("init", "-q", "-b", "main")
    write("go.mod", "module example.com/t\n\ngo 1.21")
    write("main.go", "package main\n\nfunc main() { helper() }")
    write("util.go", "package main\n\nfunc helper() {}")
    git("add", "-A")
    git("commit", "-qm", "init")
    write("main.go", "package main\n\nfunc main() { helperRenamed() }")
    write("util.go", "package main\n\nfunc helperRenamed() {}")

    vim.cmd.edit(vim.fs.joinpath(root, "main.go"))
    main = vim.api.nvim_get_current_buf()
    check("gopls attaches and resolves the definition", eventually(works, 60000))

    git("stash", "-q")
    vim.cmd("doautocmd FocusGained")
    check("after git stash", eventually(works))

    vim.lsp.buf.definition()
    check("go-to-definition opens util.go", eventually(function()
        return vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "util.go"
    end, 5000))
    vim.api.nvim_set_current_buf(main)

    -- The bug: util.go's buffer, now hidden, kept the stashed version
    git("stash", "pop", "-q")
    vim.cmd("doautocmd FocusGained")
    check("after git stash pop", eventually(works))

    vim.fn.maparg("<leader>lr", "n", false, true).callback()
    check("after <leader>lr", eventually(works))

end

vim.schedule(function()
    -- An error would otherwise leave headless nvim running
    local ok, err = xpcall(run, debug.traceback)
    if not ok then
        io.write("ERROR " .. err .. "\n")
        failures = failures + 1
    end
    vim.fn.delete(root, "rf")
    io.write(failures == 0 and "all passed\n" or (failures .. " failed\n"))
    vim.cmd("cquit " .. failures)
end)
