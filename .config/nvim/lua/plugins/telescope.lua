-- Search hidden files and folders (.github, .config, ...) too, but never .git;
-- .gitignore'd files stay out
local skip_git = { "--hidden", "--glob", "!.git" }
require("telescope").setup({
    defaults = {
        vimgrep_arguments = vim.list_extend(
            { "rg", "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
            skip_git
        ),
        -- Alt-k scrolls results right by default; free it for pane movement
        -- (config/navigation.lua), which keeps the picker open
        mappings = {
            i = { ["<M-k>"] = false },
            n = { ["<M-k>"] = false },
        },
    },
    pickers = {
        find_files = { find_command = vim.list_extend({ "rg", "--files" }, skip_git) },
        -- Errors first, then warnings, info, hints; ties stay grouped by buffer and line
        diagnostics = { sort_by = "severity" },
    },
})
-- Native fzf sorter (compiled by the PackChanged hook in init.lua); falls back
-- to the Lua sorter if the build failed
pcall(require("telescope").load_extension, "fzf")

local builtin = require("telescope.builtin")
local function map(lhs, picker, desc)
    vim.keymap.set("n", lhs, picker, { desc = desc })
end

-- File search and grep run from the current buffer's project root (git root),
-- wherever nvim was started; the capital versions use nvim's working directory
local in_project = require("config.root").in_project

map("<leader>ff", in_project(builtin.find_files, "Find Files"), "Find files in project")
map("<leader>fg", in_project(builtin.live_grep, "Live Grep"), "Grep in project")
map("<leader>fw", in_project(builtin.grep_string, "Grep Word"), "Grep word under cursor in project")
map("<leader>fF", builtin.find_files, "Find files in working directory")
map("<leader>fG", builtin.live_grep, "Grep in working directory")
map("<leader>fb", builtin.buffers, "Find buffers")
map("<leader>fo", in_project(builtin.oldfiles, "Recent Files"), "Recent files in project")
map("<leader>fO", builtin.oldfiles, "Recent files everywhere")
map("<leader>fh", builtin.help_tags, "Search help")
map("<leader>fk", builtin.keymaps, "Search keymaps")
-- Resume reshows the cached results, so a git status picker would list the
-- files as they were when it closed; that one runs git again instead, in the
-- same project and with the same prompt text, back on the file that was
-- highlighted (it can move, e.g. once staged)
map("<leader>fr", function()
    local last = (require("telescope.state").get_global_key("cached_pickers") or {})[1]
    if not (last and vim.startswith(last.prompt_title or "", "Git Status")) then
        return builtin.resume()
    end
    -- _selection_entry is telescope's internal field for the highlighted entry
    -- (no public getter once the picker is closed); if it's ever renamed, this
    -- is nil and the picker just starts at the top
    local file = last._selection_entry and last._selection_entry.value
    builtin.git_status({
        cwd = last.cwd,
        prompt_title = last.prompt_title,
        default_text = last.cache_picker.cached_prompt,
        -- Runs each time the results finish loading; only the first load
        -- moves the selection, later ones (typing, <Tab>) are left alone
        _completion_callbacks = {
            function(picker)
                if not file then
                    return
                end
                local index = 1
                for entry in picker.manager:iter() do
                    if entry.value == file then
                        picker:set_selection(picker:get_row(index))
                        break
                    end
                    index = index + 1
                end
                file = nil
            end,
        },
    })
end, "Resume last search")
map("<leader>fd", builtin.diagnostics, "Diagnostics")
map("<leader>fs", builtin.lsp_document_symbols, "Symbols in file")
map("<leader>fS", builtin.lsp_dynamic_workspace_symbols, "Symbols in project")
map("<leader>gs", in_project(builtin.git_status, "Git Status"), "Git status")
