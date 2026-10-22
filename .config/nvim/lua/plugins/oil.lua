require("oil").setup({
    default_file_explorer = true,
    skip_confirm_for_simple_edits = true,
    -- Reload the listing when files are added, removed or renamed outside nvim
    watch_for_changes = true,
    columns = {
        "icon",
    },
    view_options = {
        show_hidden = true,
    }
})

vim.keymap.set("n", "-", "<cmd>Oil<cr>", {
    desc = "Open parent directory",
})
