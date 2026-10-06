local nvim_config = vim.fn.stdpath("config")

return {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    -- The nvim config has no .git of its own (the dotfiles repo is bare), so
    -- give it its config directory as the root; otherwise the usual markers
    root_dir = function(bufnr, on_dir)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if vim.startswith(name, nvim_config .. "/") then
            on_dir(nvim_config)
        else
            on_dir(vim.fs.root(bufnr, { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" }))
        end
    end,
    settings = { Lua = {} },
    -- In the nvim config, teach it about LuaJIT, the vim.* API and the plugins
    -- (vim.pack), so require("telescope...") and MiniIcons resolve
    on_init = function(client)
        if client.root_dir ~= nvim_config then
            return
        end
        client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
            runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
            workspace = {
                checkThirdParty = false,
                library = { vim.env.VIMRUNTIME, vim.fn.stdpath("data") .. "/site/pack/core/opt" },
            },
        })
    end,
}
