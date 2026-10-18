-- Inside tmux, keep a Session.vim in nvim's working directory up to date, so
-- tmux-resurrect can bring back the buffers, splits and tabs after a reboot
-- (it restarts nvim with `nvim -S` when the file exists, see ~/.tmux.conf).
-- The file is removed again when nvim is quit normally, and ignored by git
-- through ~/.config/git/ignore.
if not vim.env.TMUX then
    return
end

-- No terminals (they'd come back as fresh shells), help or empty windows
vim.opt.sessionoptions = { "buffers", "curdir", "folds", "tabpages", "winsize" }

local group = vim.api.nvim_create_augroup("session", { clear = true })
-- The file this nvim wrote, in the directory it was in at the time
local written
local timer = assert(vim.uv.new_timer())

local function save()
    -- The command window and floats can't be saved from; wait for the next event
    if vim.fn.getcmdwintype() ~= "" or vim.api.nvim_win_get_config(0).relative ~= "" then
        return
    end
    local file = vim.fs.joinpath(vim.fn.getcwd(), "Session.vim")
    -- Leave alone a Session.vim this nvim didn't write or start from: another
    -- nvim's in the same directory (including a short-lived one, like bash's
    -- Ctrl-X Ctrl-E), or one made by hand. Once it's gone, this nvim takes over.
    if file ~= written and file ~= vim.v.this_session and vim.uv.fs_stat(file) then
        if written then
            os.remove(written)
            written = nil
        end
        return
    end
    if pcall(vim.cmd.mksession, { file, bang = true, mods = { silent = true } }) then
        -- After a :cd the old file is out of date, and the new one replaces it
        if written and written ~= file then
            os.remove(written)
        end
        written = file
    end
end

-- Only for nvim started to edit files, not as git's commit or rebase editor
-- or a man pager
vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
        local ft = vim.bo.filetype
        if vim.bo.buftype ~= "" or ft == "gitcommit" or ft == "gitrebase" or ft == "man" then
            return
        end
        -- Batched: a burst of events (opening a file into a new split) saves once
        vim.api.nvim_create_autocmd({ "BufEnter", "WinClosed", "TabClosed", "DirChanged", "FocusLost" }, {
            group = group,
            callback = function()
                timer:start(1000, 0, vim.schedule_wrap(save))
            end,
        })
        save()
    end,
})

-- Quitting normally means there's nothing to restore. tmux closing the pane
-- (a reboot, kill-server) also ends up here, as a signal; keep the file then.
vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
        timer:stop()
        if written and vim.v.dying == 0 then
            os.remove(written)
        end
    end,
})
