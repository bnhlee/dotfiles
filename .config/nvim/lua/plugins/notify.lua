-- Messages from vim.notify pop up in the top-right corner instead of the
-- command line, along with LSP progress (e.g. gopls loading)
require("mini.notify").setup({
    -- Just the message in the popup; the history adds the time (below)
    content = {
        format = function(notif)
            return notif.msg
        end,
    },
})

-- The history uses the same format setting, so switch to the default
-- timestamped one while it builds its buffer
vim.keymap.set("n", "<leader>n", function()
    local content = MiniNotify.config.content
    local format = content.format
    content.format = MiniNotify.default_format
    local ok, err = pcall(MiniNotify.show_history)
    content.format = format
    if not ok then
        error(err, 0)
    end
end, { desc = "Notification history" })
