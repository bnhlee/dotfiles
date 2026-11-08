-- Run `go test` / `go run`. Runs that show output use a terminal split at the
-- bottom (reused between runs; q closes it); tests run in the background and
-- only open it when they fail.
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

-- The background run from a quiet command, if one is going
local quiet_job

-- Open a split at the bottom; on_open fills it, and q closes it. The cursor
-- goes back to the current window unless focus is set
local function open_split(on_open, focus)
    local src_win = vim.api.nvim_get_current_win()
    vim.cmd("botright 15new")
    term_buf = vim.api.nvim_get_current_buf()
    on_open()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = term_buf, desc = "Close output" })
    if not focus then
        vim.api.nvim_set_current_win(src_win)
    end
end

-- mini.notify notification for the current quiet run: shows while it runs,
-- then changes to the result and stays a few seconds
local status_id

local function finish_status(msg, level, hl)
    -- Kept here, since by the time the timer fires a new run may have replaced status_id
    local id = status_id
    -- update errors if the notification is gone, e.g. after MiniNotify.clear()
    pcall(MiniNotify.update, id, { msg = msg, level = level, hl_group = hl })
    vim.defer_fn(function()
        MiniNotify.remove(id)
    end, 3000)
end

-- The job runs in its own process group (detach), so signal the whole group:
-- go test leaves the test binary running if only the go process is killed
local function kill_quiet_job()
    if quiet_job then
        pcall(vim.uv.kill, -quiet_job.pid, "sigterm")
        quiet_job = nil
    end
end

-- Detached jobs outlive Neovim, so stop it on exit
vim.api.nvim_create_autocmd("VimLeavePre", { callback = kill_quiet_job })

-- quiet: run in the background and only open the split if the command fails,
-- showing everything it printed
local function run(cmd, cwd, quiet)
    last = { cmd = cmd, cwd = cwd, quiet = quiet }
    if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
        vim.api.nvim_buf_delete(term_buf, { force = true })
    end
    kill_quiet_job()
    MiniNotify.remove(status_id)
    local name = table.concat(cmd, " ")
    if not quiet then
        open_split(function()
            vim.fn.jobstart(cmd, { term = true, cwd = cwd })
        end)
        return
    end

    -- stdout and stderr go into one list so build errors stay in order with test output
    local chunks = {}
    local function collect(_, data)
        if data then
            table.insert(chunks, data)
        end
    end
    local job
    job = vim.system(cmd, { cwd = cwd, text = true, detach = true, stdout = collect, stderr = collect }, function(res)
        vim.schedule(function()
            -- A newer run killed this one; its result no longer matters
            if quiet_job ~= job then
                return
            end
            quiet_job = nil
            -- code is 0 when killed by a signal (e.g. the OOM killer), so check both
            if res.code == 0 and res.signal == 0 then
                -- go test also passes when nothing ran (-run matched nothing, or build
                -- tags left no test files); a package that ran tests prints an "ok" line
                -- without "[no tests to run]"
                local ran = vim.iter(vim.split(table.concat(chunks), "\n")):any(function(line)
                    return line:match("^ok%s") and not line:find("[no tests to run]", 1, true)
                end)
                if ran then
                    finish_status("✓ PASS  " .. name, "INFO", "DiagnosticOk")
                else
                    finish_status("⚠ NO TESTS RAN  " .. name, "WARN", "DiagnosticWarn")
                end
                return
            end
            finish_status("✗ FAIL  " .. name, "ERROR", "DiagnosticError")
            -- The split takes focus, and it can't be typed into
            vim.cmd.stopinsert()
            open_split(function()
                local lines = vim.split(table.concat(chunks), "\n", { trimempty = true })
                vim.api.nvim_buf_set_lines(term_buf, 0, -1, false, lines)
                vim.bo[term_buf].buftype = "nofile"
                vim.bo[term_buf].bufhidden = "wipe"
                vim.bo[term_buf].modifiable = false
                -- Start at the end, where go test prints the FAIL summary
                vim.api.nvim_win_set_cursor(0, { math.max(#lines, 1), 0 })
            end, true)
        end)
    end)
    quiet_job = job
    -- Added only once the job has started: if vim.system throws (e.g. go not
    -- on PATH), nothing would ever remove it. The exit callback is scheduled,
    -- so it can't run before this
    status_id = MiniNotify.add("… " .. name, "INFO", "DiagnosticInfo")
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
        run({ "go", "test", "-v", "-count=1", "-run", pattern, "." }, pkg_dir(), true)
    end
end

function M.package()
    run({ "go", "test", "-count=1", "." }, pkg_dir(), true)
end

function M.all()
    run({ "go", "test", "-count=1", "./..." }, module_root(), true)
end

function M.go_run()
    run({ "go", "run", "." }, pkg_dir())
end

function M.last()
    if not last then
        vim.notify("Nothing run yet", vim.log.levels.WARN)
        return
    end
    run(last.cmd, last.cwd, last.quiet)
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
