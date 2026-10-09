-- Keeps LSP servers in sync with files changed on disk outside nvim (a git
-- checkout, stash or pull, or an agent editing files). Without inotifywait
-- (see config/lsp.lua) nvim doesn't tell servers about those changes. So when
-- focus comes back to nvim, a :Term is left, or a :! or fugitive command
-- finishes, find what changed with git and send the servers a
-- didChangeWatchedFiles notification for those files, as a file watcher would.
-- No restart, so several changes in a row (stash then pop) can't cut off a
-- server mid-load.
--
-- Set up from plugins/lint.lua, which also re-lints the changed buffers.
-- Tests: tests/lsp_sync.lua.
local M = {}

-- Called with each open buffer in a directory with changed files
local on_changed = function(_) end

-- Git state of each LSP project, by git root
local fingerprints = {}

-- Reload files changed on disk, so servers aren't left holding stale
-- contents. A buffer whose file was deleted (e.g. renamed by a git checkout)
-- is wiped if it isn't on screen. If it is, it stays, so the layout doesn't
-- change, but the servers are detached from it so they stop seeing the old
-- contents, and reattach if the file comes back (e.g. git stash pop).
-- Buffers with unsaved edits, and new files not saved yet, are left alone.
function M.sync_buffers()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        -- Local files only, not e.g. scp:// buffers
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" and name:sub(1, 1) == "/" then
            if vim.uv.fs_stat(name) then
                -- A plain :checktime leaves buffers that aren't in a window
                -- (e.g. one opened by go-to-definition) until you enter them,
                -- and the servers keep their old contents meanwhile. Checking
                -- from inside the buffer reloads it now.
                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd.checktime(bufnr)
                end)
                if vim.b[bufnr].lsp_detached then
                    vim.b[bufnr].lsp_detached = nil
                    -- Reattach the way vim.lsp.enable() attaches on open
                    pcall(vim.api.nvim_exec_autocmds, "FileType", { group = "nvim.lsp.enable", buffer = bufnr })
                end
            elseif vim.b[bufnr].on_disk and not vim.bo[bufnr].modified then
                if #vim.fn.win_findbuf(bufnr) == 0 then
                    vim.api.nvim_buf_delete(bufnr, {})
                elseif not vim.b[bufnr].lsp_detached then
                    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
                        vim.lsp.buf_detach_client(bufnr, client.id)
                    end
                    vim.b[bufnr].lsp_detached = true
                end
            end
        end
    end
end

-- A project's fingerprint is its current commit, plus the size and mtime of
-- every file that differs from it (changed, staged, deleted or untracked; not
-- ignored ones). The stat catches repeat edits to a file that was already
-- changed. Git's status letters are left out, so staging or unstaging, which
-- doesn't touch the file on disk, doesn't count as a change.
function M.file_state(file)
    local stat = vim.uv.fs_stat(file)
    return stat and ("%d.%d %d"):format(stat.mtime.sec, stat.mtime.nsec, stat.size) or "deleted"
end

function M.fingerprint(root)
    local head = vim.system({ "git", "rev-parse", "HEAD" }, { cwd = root }):wait()
    -- --no-optional-locks so this doesn't take git's index lock while an agent
    -- or the shell is running git in the same repo
    local status = vim.system(
        { "git", "--no-optional-locks", "status", "--porcelain", "-z", "--untracked-files=all" },
        { cwd = root }
    ):wait()
    if status.code ~= 0 then
        return nil
    end
    local files = {}
    local fields = vim.split(status.stdout, "\0", { plain = true })
    local i = 1
    while i <= #fields do
        local entry = fields[i]
        if entry ~= "" then
            -- Entries are "XY path"
            local path = entry:sub(4)
            files[path] = M.file_state(vim.fs.joinpath(root, path))
            -- Renames and copies are followed by a field with the old path
            if entry:match("^[RC]") or entry:match("^.[RC]") then
                i = i + 1
                files[fields[i]] = M.file_state(vim.fs.joinpath(root, fields[i]))
            end
        end
        i = i + 1
    end
    -- No commit yet in a fresh repo: rev-parse fails and prints "HEAD"
    return { head = head.code == 0 and vim.trim(head.stdout) or "", files = files }
end

-- Files (relative to root) whose contents changed between two fingerprints
function M.changed_files(root, old, new)
    local candidates = {}
    for path in pairs(old.files) do
        candidates[path] = true
    end
    for path in pairs(new.files) do
        candidates[path] = true
    end
    -- A new commit (checkout, pull, reset) can also change files that were
    -- unchanged before and after, so include every file that differs between
    -- the two commits
    if old.head ~= new.head and old.head ~= "" and new.head ~= "" then
        local diff = vim.system({ "git", "diff", "--name-only", "-z", old.head, new.head }, { cwd = root }):wait()
        for _, path in ipairs(vim.split(diff.stdout or "", "\0", { plain = true, trimempty = true })) do
            candidates[path] = true
        end
    end
    local paths = {}
    for path in pairs(candidates) do
        -- A file that had changed before is compared with its recorded size
        -- and mtime, so committing it, which leaves the file on disk as it
        -- was, doesn't count. Any other file here is new to the list, so it
        -- changed.
        local before = old.files[path]
        if not before or before ~= (new.files[path] or M.file_state(vim.fs.joinpath(root, path))) then
            paths[path] = true
        end
    end
    return paths
end

local function git_root(dir)
    return dir and vim.fs.root(dir, ".git")
end

local function notify_changes(root, paths)
    local changes = {}
    for path in pairs(paths) do
        local file = vim.fs.joinpath(root, path)
        -- 2 = Changed (gopls handles new files sent as changed too), 3 = Deleted
        table.insert(changes, { uri = vim.uri_from_fname(file), type = vim.uv.fs_stat(file) and 2 or 3 })
    end
    for _, client in ipairs(vim.lsp.get_clients()) do
        -- Skip servers nvim already watches files for (inotifywait installed)
        local watched = vim.tbl_get(client.capabilities, "workspace", "didChangeWatchedFiles", "dynamicRegistration")
        if git_root(client.root_dir) == root and not watched then
            client:notify("workspace/didChangeWatchedFiles", { changes = changes })
        end
    end
end

-- Forget the recorded state, e.g. before restarting the servers; they record
-- it again as they attach
function M.reset()
    fingerprints = {}
end

function M.sync()
    local synced = false
    -- Directories with changed files: only open buffers in these get passed
    -- to on_changed (re-linted), not every buffer
    local dirs = {}
    for root, old in pairs(fingerprints) do
        local new = M.fingerprint(root)
        if new then
            local paths = M.changed_files(root, old, new)
            fingerprints[root] = new
            if next(paths) then
                if not synced then
                    M.sync_buffers()
                    synced = true
                end
                notify_changes(root, paths)
                for path in pairs(paths) do
                    dirs[vim.fs.dirname(vim.fs.joinpath(root, path))] = true
                end
            end
        end
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" and dirs[vim.fs.dirname(name)] then
            on_changed(bufnr)
        end
    end
end

-- opts.on_changed(bufnr): called with each open buffer in a directory with
-- changed files, after the servers have been told
function M.setup(opts)
    on_changed = opts and opts.on_changed or on_changed

    -- Mark buffers whose file has existed on disk, so sync_buffers can tell a
    -- file deleted outside nvim from a new one that hasn't been saved yet
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("on_disk", { clear = true }),
        callback = function(args)
            vim.b[args.buf].on_disk = true
        end,
    })

    local group = vim.api.nvim_create_augroup("lsp_auto_sync", { clear = true })

    -- Baseline: the state when a server attaches
    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local root = git_root(client and client.root_dir)
            if root and not fingerprints[root] then
                fingerprints[root] = M.fingerprint(root)
            end
        end,
    })

    -- Saving in nvim changes the fingerprint too, but the server already knows
    -- about those edits. Update just the saved file's entry, so other changes
    -- not yet synced (e.g. an agent's edits) are still found on the next check.
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        callback = function(args)
            local file = vim.api.nvim_buf_get_name(args.buf)
            local root = git_root(vim.fs.dirname(file))
            local old = root and fingerprints[root]
            local new = old and M.fingerprint(root)
            local path = new and vim.fs.relpath(root, file)
            if path then
                old.files[path] = new.files[path]
            end
        end,
    })

    -- Back from another tmux pane, out of a :Term, or after :!cmd
    vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "ShellCmdPost" }, {
        group = group,
        callback = M.sync,
    })
    -- After fugitive commands (:Git pull, :Git stash, staging, ...)
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "FugitiveChanged",
        callback = M.sync,
    })
end

return M
