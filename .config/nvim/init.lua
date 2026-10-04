require("config.options")
require("config.navigation")
require("config.keymaps")

vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        -- Rebuild treesitter parsers when nvim-treesitter is updated
        if name == "nvim-treesitter" and kind == "update" then
            vim.cmd("TSUpdate")
        end
        -- telescope-fzf-native ships C source that needs compiling
        if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
            vim.system({ "make" }, { cwd = ev.data.path }):wait()
        end
    end,
})

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.icons", },
    { src = "https://github.com/stevearc/oil.nvim", },
    { src = "https://github.com/nvim-lua/plenary.nvim", },
    { src = "https://github.com/nvim-telescope/telescope.nvim", },
    { src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim", },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main", },
    { src = "https://github.com/lewis6991/gitsigns.nvim", },
    -- Pinned to releases so blink can download its prebuilt fuzzy matcher
    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1") },
    { src = "https://github.com/tpope/vim-fugitive", },
    { src = "https://github.com/mfussenegger/nvim-lint", },
    { src = "https://github.com/mfussenegger/nvim-dap", },
    { src = "https://github.com/leoluz/nvim-dap-go", },
    { src = "https://github.com/igorlfs/nvim-dap-view", },
})
require("plugins.icons")
require("plugins.oil")
require("plugins.telescope")
require("plugins.treesitter")
require("plugins.gitsigns")
require("plugins.fugitive")
require("plugins.dap")
require("plugins.lint")
require("plugins.blink")
require("config.lsp")
require("config.gotest")
require("config.terminal")
