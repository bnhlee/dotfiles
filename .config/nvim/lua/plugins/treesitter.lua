local M = {}

-- Parsers are compiled with the tree-sitter CLI; no-op once installed.
-- The task is kept so dotfiles-bootstrap can wait for it to finish.
M.install_task = require("nvim-treesitter").install({
    "go", "gomod", "gosum", "gowork",
    "bash", "lua", "vim", "vimdoc", "query",
    "json", "yaml", "toml",
    "markdown", "markdown_inline",
    "diff", "gitcommit", "git_rebase",
    "dockerfile",
})

-- Highlight and fold with treesitter for any filetype that has a parser
vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
            vim.wo[0][0].foldmethod = "expr"
            vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end
    end,
})

return M
