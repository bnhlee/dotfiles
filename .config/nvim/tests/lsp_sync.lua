-- Tests for config/lsp_sync.lua: which file changes count (fingerprint and
-- changed_files), and how open buffers are synced (sync_buffers). Uses
-- temporary git repos and no language server, so it runs in a few seconds.
-- Run: nvim --clean --headless -l ~/.config/nvim/tests/lsp_sync.lua
local config_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(arg[0])))
vim.opt.rtp:prepend(config_dir)
local sync = require("config.lsp_sync")
sync.setup({})

-- Keep the user's git config (hooks, signing, ...) out of the test repos
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.GIT_AUTHOR_NAME, vim.env.GIT_AUTHOR_EMAIL = "test", "test@example.com"
vim.env.GIT_COMMITTER_NAME, vim.env.GIT_COMMITTER_EMAIL = "test", "test@example.com"

local failures, roots = 0, {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("ok   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. "\n     " .. tostring(err))
    end
end

local function eq(actual, expected)
    if not vim.deep_equal(actual, expected) then
        error(("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)), 2)
    end
end

local function git(root, ...)
    local res = vim.system({ "git", ... }, { cwd = root }):wait()
    assert(res.code == 0, ("git %s: %s"):format(table.concat({ ... }, " "), res.stderr))
end

-- Each write gets its own mtime, 10s after the last, so two quick writes
-- can't end up with the same timestamp. (nvim's reload check ignores mtime
-- differences of up to 1s on Linux, so 1s apart isn't enough.)
local mtime = os.time()
local function write(root, path, text)
    local file = vim.fs.joinpath(root, path)
    vim.fn.mkdir(vim.fs.dirname(file), "p")
    vim.fn.writefile(vim.split(text, "\n"), file)
    mtime = mtime + 10
    vim.uv.fs_utime(file, mtime, mtime)
end

-- A new repo with files { path = text }, committed unless commit is false
local function repo(files, commit)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    table.insert(roots, root)
    git(root, "init", "-q", "-b", "main")
    for path, text in pairs(files) do
        write(root, path, text)
    end
    if commit ~= false then
        git(root, "add", "-A")
        git(root, "commit", "-qm", "init")
    end
    return root
end

-- The files (sorted) that count as changed by running fn
local function changes(root, fn)
    local old = sync.fingerprint(root)
    fn()
    local paths = vim.tbl_keys(sync.changed_files(root, old, sync.fingerprint(root)))
    table.sort(paths)
    return paths
end

local function default_repo()
    return repo({ ["a.go"] = "package a", ["b.go"] = "package a", [".gitignore"] = "*.log" })
end

print("-- fingerprint / changed_files")

test("nothing changed", function()
    local root = default_repo()
    eq(changes(root, function() end), {})
end)

test("editing a clean tracked file", function()
    local root = default_repo()
    eq(changes(root, function() write(root, "a.go", "package a // 1") end), { "a.go" })
end)

test("editing an already changed file again", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    eq(changes(root, function() write(root, "a.go", "package a // 2") end), { "a.go" })
end)

test("staging a change doesn't count", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    eq(changes(root, function() git(root, "add", "a.go") end), {})
end)

test("unstaging a change doesn't count", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    git(root, "add", "a.go")
    eq(changes(root, function() git(root, "reset", "-q", "a.go") end), {})
end)

test("committing a change doesn't count", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    eq(changes(root, function() git(root, "commit", "-qam", "change") end), {})
end)

test("checking out a commit that changes a clean file", function()
    local root = default_repo()
    write(root, "b.go", "package a // 1")
    git(root, "commit", "-qam", "change b")
    eq(changes(root, function() git(root, "checkout", "-q", "HEAD~1") end), { "b.go" })
    eq(changes(root, function() git(root, "checkout", "-q", "main") end), { "b.go" })
end)

test("stash, then pop", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    eq(changes(root, function() git(root, "stash", "-q") end), { "a.go" })
    eq(changes(root, function() git(root, "stash", "pop", "-q") end), { "a.go" })
end)

test("reverting a changed file", function()
    local root = default_repo()
    write(root, "a.go", "package a // 1")
    eq(changes(root, function() git(root, "checkout", "--", "a.go") end), { "a.go" })
end)

test("new untracked file in a new folder", function()
    local root = default_repo()
    eq(changes(root, function() write(root, "new/dir/c.go", "package dir") end), { "new/dir/c.go" })
end)

test("editing an untracked file again", function()
    local root = default_repo()
    write(root, "c.go", "package a")
    eq(changes(root, function() write(root, "c.go", "package a // 1") end), { "c.go" })
end)

test("deleting a tracked file", function()
    local root = default_repo()
    eq(changes(root, function() os.remove(vim.fs.joinpath(root, "a.go")) end), { "a.go" })
    eq(sync.fingerprint(root).files["a.go"], "deleted")
end)

test("git mv counts both names", function()
    local root = default_repo()
    eq(changes(root, function() git(root, "mv", "a.go", "renamed.go") end), { "a.go", "renamed.go" })
end)

test("ignored files don't count", function()
    local root = default_repo()
    eq(changes(root, function() write(root, "debug.log", "x") end), {})
end)

test("repo with no commits, then its first commit", function()
    local root = repo({ ["a.go"] = "package a" }, false)
    eq(sync.fingerprint(root).head, "")
    eq(changes(root, function()
        git(root, "add", "-A")
        git(root, "commit", "-qm", "first")
    end), {})
    eq(changes(root, function() write(root, "a.go", "package a // 1") end), { "a.go" })
end)

print("-- sync_buffers")

-- Start each test with a single window and no buffers
local function fresh()
    vim.cmd("silent! only")
    vim.cmd("silent! %bwipeout!")
end

local function lines(bufnr)
    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

test("reloads a buffer that isn't in a window", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "a.go"))
    local a = vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fs.joinpath(root, "b.go"))
    write(root, "a.go", "package a // changed")
    sync.sync_buffers()
    eq(lines(a), "package a // changed")
end)

test("reloads a buffer in a window", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "a.go"))
    local a = vim.api.nvim_get_current_buf()
    write(root, "a.go", "package a // changed")
    sync.sync_buffers()
    eq(lines(a), "package a // changed")
end)

test("keeps a new file that hasn't been saved", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "new.go"))
    local new = vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fs.joinpath(root, "a.go"))
    sync.sync_buffers()
    eq(vim.api.nvim_buf_is_valid(new), true)
end)

test("wipes a buffer that isn't in a window when its file is deleted", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "a.go"))
    local a = vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fs.joinpath(root, "b.go"))
    os.remove(vim.fs.joinpath(root, "a.go"))
    sync.sync_buffers()
    eq(vim.api.nvim_buf_is_valid(a), false)
end)

test("keeps a deleted file's buffer and window when it's on screen", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "b.go"))
    vim.cmd.vsplit(vim.fs.joinpath(root, "a.go"))
    local a = vim.api.nvim_get_current_buf()
    os.remove(vim.fs.joinpath(root, "a.go"))
    sync.sync_buffers()
    eq(vim.api.nvim_buf_is_valid(a), true)
    eq(#vim.api.nvim_list_wins(), 2)
    eq(vim.b[a].lsp_detached, true)
end)

test("keeps a deleted file's buffer if it has unsaved edits", function()
    fresh()
    local root = default_repo()
    vim.cmd.edit(vim.fs.joinpath(root, "a.go"))
    local a = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(a, 0, -1, false, { "package a // unsaved" })
    vim.cmd.edit(vim.fs.joinpath(root, "b.go"))
    os.remove(vim.fs.joinpath(root, "a.go"))
    sync.sync_buffers()
    eq(vim.api.nvim_buf_is_valid(a), true)
end)

test("leaves non-local buffers alone", function()
    fresh()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "scp://host/a.go")
    vim.b[buf].on_disk = true
    sync.sync_buffers()
    eq(vim.api.nvim_buf_is_valid(buf), true)
end)

for _, root in ipairs(roots) do
    vim.fn.delete(root, "rf")
end
print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
