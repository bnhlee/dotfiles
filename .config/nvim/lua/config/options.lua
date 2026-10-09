vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Go tools (gopls, dlv, golangci-lint) live in ~/go/bin and the other language
-- servers in ~/.local/bin, which may not be on PATH when nvim is started
-- outside a shell
for _, dir in ipairs({ "~/go/bin", "~/.local/bin" }) do
    dir = vim.fn.expand(dir)
    if not vim.tbl_contains(vim.split(vim.env.PATH, ":"), dir) then
        vim.env.PATH = dir .. ":" .. vim.env.PATH
    end
end

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 4

-- Case-insensitive search, unless the pattern has a capital letter
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- Preview :s substitutions as you type, with off-screen matches in a split
vim.opt.inccommand = "split"

-- New splits open to the right and below, rather than left and above
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.wrap = false

-- Keep undo history after closing a file
vim.opt.undofile = true
-- No swap files (avoids the swap prompt); unsaved changes are lost on a crash
vim.opt.swapfile = false
-- Reload open files changed on disk (e.g. by git checkout) when coming back to
-- nvim or switching buffers, including from a :Term inside nvim. 'autoread'
-- (on by default) reloads them without asking if they have no unsaved edits.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
    group = vim.api.nvim_create_augroup("checktime", { clear = true }),
    callback = function()
        if vim.fn.getcmdwintype() == "" then
            vim.cmd.checktime()
        end
    end,
})
-- Yank and paste through the system clipboard (uses xclip / wl-copy)
vim.opt.clipboard = "unnamedplus"

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
