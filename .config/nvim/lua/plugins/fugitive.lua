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
map("<leader>gp", "<cmd>Git push<cr>", "Git push")
map("<leader>gP", "<cmd>Git pull --rebase<cr>", "Git pull")
map("<leader>gb", "<cmd>Git blame<cr>", "Git blame file")
map("<leader>gd", "<cmd>Gvdiffsplit<cr>", "Diff file against index")
map("<leader>gw", "<cmd>Gwrite<cr>", "Stage file")
-- Telescope's git pickers default to nvim's working directory, so run them
-- from the current buffer's repo instead
local in_project = require("config.root").in_project
map("<leader>gl", in_project(builtin.git_commits, "Git Log"), "Git log")
map("<leader>gL", in_project(builtin.git_bcommits, "Git Log (file)"), "Git log for file")
map("<leader>gB", in_project(builtin.git_branches, "Git Branches"), "Git branches")
