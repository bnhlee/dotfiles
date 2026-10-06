require("telescope").setup({})
-- Native fzf sorter (compiled by the PackChanged hook in init.lua); falls back
-- to the Lua sorter if the build failed
pcall(require("telescope").load_extension, "fzf")

local builtin = require("telescope.builtin")
local function map(lhs, picker, desc)
    vim.keymap.set("n", lhs, picker, { desc = desc })
end

-- File search and grep run from the current buffer's project root (git root),
-- wherever nvim was started; the capital versions use nvim's working directory
local root = require("config.root")
local function in_project(picker, title)
    return function()
        local dir = root.get()
        picker({ cwd = dir, prompt_title = ("%s (%s)"):format(title, vim.fs.basename(dir)) })
    end
end

map("<leader>ff", in_project(builtin.find_files, "Find Files"), "Find files in project")
map("<leader>fg", in_project(builtin.live_grep, "Live Grep"), "Grep in project")
map("<leader>fw", in_project(builtin.grep_string, "Grep Word"), "Grep word under cursor in project")
map("<leader>fF", builtin.find_files, "Find files in working directory")
map("<leader>fG", builtin.live_grep, "Grep in working directory")
map("<leader>fb", builtin.buffers, "Find buffers")
map("<leader>fo", builtin.oldfiles, "Recent files")
map("<leader>fh", builtin.help_tags, "Search help")
map("<leader>fk", builtin.keymaps, "Search keymaps")
map("<leader>fr", builtin.resume, "Resume last search")
map("<leader>fd", builtin.diagnostics, "Diagnostics")
map("<leader>fs", builtin.lsp_document_symbols, "Symbols in file")
map("<leader>fS", builtin.lsp_dynamic_workspace_symbols, "Symbols in project")
map("<leader>gs", builtin.git_status, "Git status")
