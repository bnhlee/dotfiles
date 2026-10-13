-- Alt-hjkl moves between nvim splits, and on into the neighbouring tmux pane
-- when there's no split in that direction. ~/.tmux.conf does the reverse.
local M = {}

local tmux_direction = { h = "L", j = "D", k = "U", l = "R" }

function M.tmux(dir)
    if vim.env.TMUX then
        vim.system({ "tmux", "select-pane", "-" .. tmux_direction[dir] })
    end
end

-- No split that way: the edge of the screen, or a floating window (a
-- Telescope picker, a focused hover), which has no neighbours and closes when
-- left, so Alt-hjkl from one goes straight to tmux
local function at_edge(dir)
    return vim.api.nvim_win_get_config(0).relative ~= "" or vim.fn.winnr(dir) == vim.fn.winnr()
end

function M.navigate(dir)
    if at_edge(dir) then
        M.tmux(dir)
    else
        vim.cmd.wincmd(dir)
    end
end

-- From insert, visual, terminal or command-line mode (an unmapped Alt-key acts
-- like <Esc> and drops out of it). Going to a tmux pane leaves nvim as it is,
-- so the mode, selection, half-typed command or Telescope search are still
-- there on the way back. Moving to a split has to leave the mode first (gv
-- brings a selection back). A command line is saved to history: : then <Up>.
function M.navigate_mode(dir)
    if at_edge(dir) then
        M.tmux(dir)
        return ""
    end
    if vim.fn.mode() == "c" and vim.fn.getcmdline() ~= "" then
        vim.fn.histadd(vim.fn.getcmdtype(), vim.fn.getcmdline())
    end
    return "<C-\\><C-n><Cmd>lua require('config.navigation').navigate('" .. dir .. "')<CR>"
end

for dir in pairs(tmux_direction) do
    local lhs = "<M-" .. dir .. ">"
    local desc = "Move to split or tmux pane"
    vim.keymap.set("n", lhs, function() M.navigate(dir) end, { desc = desc })
    vim.keymap.set({ "i", "x", "s", "t", "c" }, lhs, function() return M.navigate_mode(dir) end,
        { expr = true, desc = desc })
end

return M
