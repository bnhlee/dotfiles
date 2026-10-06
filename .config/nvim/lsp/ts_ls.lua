-- typescript-language-server wraps tsserver. It uses the project's own
-- node_modules/typescript when there is one, otherwise the TypeScript 6
-- installed next to it by dotfiles-bootstrap.
return {
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    init_options = { hostInfo = "neovim" },
}
