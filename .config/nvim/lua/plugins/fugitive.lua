-- gitsigns handles hunks (<leader>h*); fugitive is the full git client.
-- In the :Git status window: s stage, u unstage, = inline diff, cc commit,
-- dv vertical diff, g? for the full list.
local builtin = require("telescope.builtin")
local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

-- In its own tab, so cc's commit split doesn't squeeze the editing windows
map("<leader>gg", "<cmd>tab Git<cr>", "Git status (fugitive)")
map("<leader>gc", "<cmd>Git commit<cr>", "Git commit")
-- Quiet when it works: fugitive prints git's progress and waits for Enter
-- either way, so its output is only shown when the command fails
local function quiet_git(args)
    return function()
        local name = "Git " .. args:match("^%S+")
        local before = vim.fn.FugitiveResult().file
        local ok, err = pcall(vim.cmd, "silent Git " .. args)
        local result = vim.fn.FugitiveResult()
        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
        elseif result.file ~= before and result.exit_status ~= 0 then
            -- Progress lines are rewritten in place with \r; keep their last state
            local lines = vim.tbl_map(function(line)
                return line:match("([^\r]*)\r*$")
            end, vim.fn.readfile(result.file))
            vim.notify(name .. " failed:\n" .. table.concat(lines, "\n"), vim.log.levels.ERROR)
        else
            vim.notify(name .. " done")
        end
    end
end
map("<leader>gp", quiet_git("push"), "Git push")
map("<leader>gP", quiet_git("pull --rebase"), "Git pull")
map("<leader>gf", quiet_git("fetch"), "Git fetch")
map("<leader>gB", "<cmd>Git blame<cr>", "Git blame file")
map("<leader>gd", "<cmd>Gvdiffsplit<cr>", "Diff file against index")
map("<leader>gw", "<cmd>Gwrite<cr>", "Stage file")
-- Telescope's git pickers default to nvim's working directory, so run them
-- from the current buffer's repo instead
local in_project = require("config.root").in_project
map("<leader>gl", in_project(builtin.git_commits, "Git Log"), "Git log")
map("<leader>gL", in_project(builtin.git_bcommits, "Git Log (file)"), "Git log for file")
map("<leader>gb", in_project(builtin.git_branches, "Git Branches"), "Git branches")

-- Files changed on this branch: everything differing from where it split off
-- the default branch (origin/HEAD, else origin's or the local main or master),
-- uncommitted edits and new untracked files included, deleted files left out
local function branch_files(opts)
    local function git(...)
        local res = vim.system({ "git", ... }, { cwd = opts.cwd, text = true }):wait()
        return res.code == 0 and vim.trim(res.stdout) or nil
    end
    -- Both commands below list paths from the repo root, and in_project's
    -- directory may be below it (nvim's working directory, when no file is open)
    local root = git("rev-parse", "--show-toplevel")
    if not root then
        vim.notify("Not in a git repository: " .. opts.cwd, vim.log.levels.WARN)
        return
    end
    opts.cwd = root
    -- The remote branches come first, since the local ones may be behind
    local base = git("rev-parse", "--abbrev-ref", "origin/HEAD")
    for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
        if base then
            break
        end
        base = git("rev-parse", "--verify", "--quiet", ref) and ref
    end
    if not base then
        vim.notify("No origin/HEAD, main or master to compare against", vim.log.levels.WARN)
        return
    end
    opts.prompt_title = opts.prompt_title .. " vs " .. base
    -- quotePath off, or names with non-ASCII characters come out quoted and escaped.
    opts.find_command = {
        "sh",
        "-c",
        'git -c core.quotePath=false diff --name-only --diff-filter=d --merge-base "$1"'
            .. "; git -c core.quotePath=false ls-files --others --exclude-standard --full-name",
        "sh",
        base,
    }
    builtin.find_files(opts)
end
map("<leader>gF", in_project(branch_files, "Branch Files"), "Files changed on branch")
