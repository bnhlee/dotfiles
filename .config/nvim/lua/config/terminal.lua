-- Start typing as soon as a terminal opens. Only when it's still focused, so
-- splits that run in the background (e.g. the Go test runner) don't put the
-- previous window into insert mode.
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function(args)
        vim.schedule(function()
            if vim.api.nvim_get_current_buf() == args.buf then
                vim.cmd.startinsert()
            end
        end)
    end,
})

-- Go back into terminal mode when returning to a terminal, from another split
-- or another tmux pane (Alt-hjkl leaves terminal mode on the way out). Only
-- while its process runs: in a finished one, any key closes the buffer.
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FocusGained" }, {
    callback = function()
        local job = vim.b.terminal_job_id
        if vim.bo.buftype == "terminal" and job and vim.fn.jobwait({ job }, 0)[1] == -1 then
            vim.cmd.startinsert()
        end
    end,
})

-- Like :terminal, but starts in the project root of the current buffer
-- (see config/root.lua)
vim.api.nvim_create_user_command("Term", function(opts)
    local cwd = require("config.root").get()
    vim.cmd.enew()
    vim.fn.jobstart(opts.args ~= "" and opts.args or vim.o.shell, { term = true, cwd = cwd })
    vim.b.close_on_exit = true
end, { nargs = "*", complete = "shellcmd", desc = "Terminal at the git root" })

-- Close :Term terminals when the shell exits (e.g. Ctrl-D), instead of
-- waiting for a keypress. Windows keep open and go back to the buffer they
-- showed before. Other terminals, like test output, stay open.
vim.api.nvim_create_autocmd("TermClose", {
    callback = function(args)
        local buf = args.buf
        if not vim.b[buf].close_on_exit then
            return
        end
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                vim.api.nvim_win_call(win, function()
                    local alt = vim.fn.bufnr("#")
                    if alt > 0 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) then
                        vim.cmd.buffer(alt)
                    else
                        vim.cmd.enew()
                    end
                end)
            end
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end,
})

vim.keymap.set("n", "<leader>tt", "<cmd>Term<cr>", { desc = "Open terminal at the git root" })

-- Make :ter / :terminal run :Term
for _, abbr in ipairs({ "ter", "term", "terminal" }) do
    vim.keymap.set("ca", abbr, function()
        return (vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == abbr) and "Term" or abbr
    end, { expr = true })
end
