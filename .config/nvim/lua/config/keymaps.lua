-- Splits (move between them with Alt-hjkl, see navigation.lua)
local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>sv", "<cmd>vsplit<cr>", "Split vertically")
map("<leader>sh", "<cmd>split<cr>", "Split horizontally")
map("<leader>sq", "<cmd>close<cr>", "Close split")
map("<leader>so", "<cmd>only<cr>", "Close other splits")
map("<leader>se", "<C-w>=", "Make splits equal size")

-- Centre the screen on each search match. zv opens folds around it, which
-- 'foldopen' doesn't do for commands run from a mapping
map("n", "nzzzv", "Next match, centred")
map("N", "Nzzzv", "Previous match, centred")
-- Clear search highlighting (<C-l> also does, along with a redraw)
map("<Esc>", "<cmd>nohlsearch<cr><Esc>", "Clear search highlight")
