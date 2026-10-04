vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Go tools (gopls, dlv, golangci-lint) live in ~/go/bin, which isn't on PATH
-- when nvim is started outside a shell
local go_bin = vim.fn.expand("~/go/bin")
if not vim.tbl_contains(vim.split(vim.env.PATH, ":"), go_bin) then
    vim.env.PATH = go_bin .. ":" .. vim.env.PATH
end

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

vim.opt.hlsearch = true

vim.opt.wrap = false

-- Always show the sign column so git/diagnostic signs don't shift the text
vim.opt.signcolumn = "yes"
-- How long the cursor sits still before CursorHold fires (gitsigns, LSP highlights)
vim.opt.updatetime = 250

-- Open files with all folds open; zM closes them all, zR reopens
vim.opt.foldlevelstart = 99
-- Show the first line of a closed fold with its normal highlighting
vim.opt.foldtext = ""

-- Built-in colorscheme (:Telescope colorscheme enable_preview=true to browse others)
-- Always dark, rather than following the terminal's detected background
vim.opt.background = "dark"
vim.cmd.colorscheme("catppuccin")
