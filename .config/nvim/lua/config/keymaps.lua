-- Splits (move between them with Alt-hjkl, see navigation.lua)
local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>sv", "<cmd>vsplit<cr>", "Split vertically")
map("<leader>sh", "<cmd>split<cr>", "Split horizontally")
map("<leader>sq", "<cmd>close<cr>", "Close split")
map("<leader>so", "<cmd>only<cr>", "Close other splits")
map("<leader>se", "<C-w>=", "Make splits equal size")
