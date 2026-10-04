-- gitsigns handles hunks (<leader>h*); fugitive is the full git client.
-- In the :Git status window: s stage, u unstage, = inline diff, cc commit,
-- dv vertical diff, g? for the full list.
local builtin = require("telescope.builtin")
local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>gg", "<cmd>Git<cr>", "Git status (fugitive)")
map("<leader>gc", "<cmd>Git commit<cr>", "Git commit")
map("<leader>gp", "<cmd>Git push<cr>", "Git push")
map("<leader>gP", "<cmd>Git pull --rebase<cr>", "Git pull")
map("<leader>gb", "<cmd>Git blame<cr>", "Git blame file")
map("<leader>gd", "<cmd>Gvdiffsplit<cr>", "Diff file against index")
map("<leader>gw", "<cmd>Gwrite<cr>", "Stage file")
map("<leader>gl", builtin.git_commits, "Git log")
map("<leader>gL", builtin.git_bcommits, "Git log for file")
map("<leader>gB", builtin.git_branches, "Git branches")
