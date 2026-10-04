require("telescope").setup({})
-- Native fzf sorter (compiled by the PackChanged hook in init.lua); falls back
-- to the Lua sorter if the build failed
pcall(require("telescope").load_extension, "fzf")

local builtin = require("telescope.builtin")
local function map(lhs, picker, desc)
    vim.keymap.set("n", lhs, picker, { desc = desc })
end

map("<leader>ff", builtin.find_files, "Find files")
map("<leader>fg", builtin.live_grep, "Grep in project")
map("<leader>fw", builtin.grep_string, "Grep word under cursor")
map("<leader>fb", builtin.buffers, "Find buffers")
map("<leader>fo", builtin.oldfiles, "Recent files")
map("<leader>fh", builtin.help_tags, "Search help")
map("<leader>fk", builtin.keymaps, "Search keymaps")
map("<leader>fr", builtin.resume, "Resume last search")
map("<leader>fd", builtin.diagnostics, "Diagnostics")
map("<leader>fs", builtin.lsp_document_symbols, "Symbols in file")
map("<leader>fS", builtin.lsp_dynamic_workspace_symbols, "Symbols in project")
map("<leader>gs", builtin.git_status, "Git status")
