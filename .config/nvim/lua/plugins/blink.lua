-- Completion menu while typing: LSP (ranked by expected type), file paths,
-- snippets and words from open buffers, with typo-tolerant fuzzy matching.
-- Also completes : commands and shows signature help inside calls.
require("blink.cmp").setup({
    keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "cancel", "fallback" },
        -- Accepts the highlighted item, or the first one if none is highlighted
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<C-y>"] = { "select_and_accept", "fallback" },
        ["<C-n>"] = { "select_next", "fallback_to_mappings" },
        ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-s>"] = { "show_signature", "hide_signature", "fallback" },
    },
    completion = {
        -- Nothing is highlighted until you move; <C-n>/<C-p> insert as they move
        list = { selection = { preselect = false, auto_insert = true } },
        -- Grey preview of what <Tab> would insert
        ghost_text = { enabled = true, show_without_selection = true },
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
    },
    signature = { enabled = true },
})
