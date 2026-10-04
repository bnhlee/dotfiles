-- Alt-hjkl moves between nvim splits, and on into the neighbouring tmux pane
-- when there's no split in that direction. ~/.tmux.conf does the reverse.
local M = {}

local tmux_direction = { h = "L", j = "D", k = "U", l = "R" }

function M.navigate(dir)
    local win = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(dir)
    if vim.api.nvim_get_current_win() == win and vim.env.TMUX then
        vim.system({ "tmux", "select-pane", "-" .. tmux_direction[dir] })
    end
end

for dir in pairs(tmux_direction) do
    local lhs = "<M-" .. dir .. ">"
    local desc = "Move to split or tmux pane"
    vim.keymap.set("n", lhs, function() M.navigate(dir) end, { desc = desc })
    -- Leave insert/terminal mode first (<C-\><C-n>), then navigate from normal mode
    vim.keymap.set({ "i", "t" }, lhs,
        "<C-\\><C-n><Cmd>lua require('config.navigation').navigate('" .. dir .. "')<CR>",
        { desc = desc })
end

return M
