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

-- Directory of the current buffer: the folder shown in oil, or the file's folder
local function buffer_dir()
    if vim.bo.filetype == "oil" then
        return require("oil").get_current_dir()
    end
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" and vim.uv.fs_stat(name) then
        return vim.fs.dirname(name)
    end
end

-- Like :terminal, but starts in the git root of the current buffer
-- (falling back to its folder, then to nvim's working directory)
vim.api.nvim_create_user_command("Term", function(opts)
    local dir = buffer_dir()
    local cwd = dir and (vim.fs.root(dir, ".git") or dir) or vim.fn.getcwd()
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
