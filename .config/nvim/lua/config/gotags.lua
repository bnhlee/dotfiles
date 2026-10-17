-- Go build tags per project, e.g. "integration,e2e", kept in a .gotags file
-- next to go.mod (ignored by git through ~/.config/git/ignore). gopls builds
-- with them, so it sees files behind //go:build integration, and go test, dlv
-- and golangci-lint started from nvim get them through GOFLAGS (nvim-wide, so
-- with two projects open, the last one loaded or set wins).
-- :GoTags integration,e2e sets and saves them, :GoTags alone clears them.
-- Starting nvim with GOFLAGS=-tags=integration works too, without saving.
local M = {}

local function path(root)
    return vim.fs.joinpath(root, ".gotags")
end

function M.read(root)
    local file = io.open(path(root))
    if not file then
        return nil
    end
    local tags = vim.trim(file:read("*a"))
    file:close()
    return tags
end

-- GOFLAGS as nvim started with it. Projects build on this rather than on the
-- current GOFLAGS, so one project's tags don't leak into the next. gopls gets
-- it as cmd_env (lsp/gopls.lua): nvim spawns gopls before before_init runs,
-- so it would otherwise inherit the previous project's GOFLAGS
M.startup_goflags = vim.env.GOFLAGS

-- nil tags: back to the startup GOFLAGS, tags and all
local function set_goflags(tags)
    if not tags then
        vim.env.GOFLAGS = M.startup_goflags
        return
    end
    local flags = vim.tbl_filter(function(flag)
        return not flag:match("^%-%-?tags=")
    end, vim.split(M.startup_goflags or "", "%s+", { trimempty = true }))
    if tags ~= "" then
        table.insert(flags, "-tags=" .. tags)
    end
    vim.env.GOFLAGS = #flags > 0 and table.concat(flags, " ") or nil
end

-- gopls's before_init (lsp/gopls.lua): start with the project's saved tags.
-- Projects without a .gotags file get whatever GOFLAGS nvim started with.
function M.before_init(_, config)
    local tags = config.root_dir and M.read(config.root_dir)
    if tags then
        config.settings.gopls.buildFlags = { "-tags=" .. tags }
    end
    set_goflags(tags)
end

vim.api.nvim_create_user_command("GoTags", function(opts)
    local clients = vim.lsp.get_clients({ bufnr = 0, name = "gopls" })
    if #clients == 0 then
        vim.notify("GoTags: no gopls attached to this buffer", vim.log.levels.WARN)
        return
    end
    local root = clients[1].root_dir
    if not root then
        vim.notify("GoTags: gopls has no project root to save tags in", vim.log.levels.WARN)
        return
    end
    -- Commas only: GOFLAGS splits on spaces, so "-tags=a b" would break it
    local tags = vim.trim(opts.args):gsub("[%s,]+", ","):gsub("^,", ""):gsub(",$", "")
    if tags ~= "" then
        local file = assert(io.open(path(root), "w"))
        file:write(tags .. "\n")
        file:close()
    else
        -- Same as a restart without .gotags: back to the startup GOFLAGS
        os.remove(path(root))
        tags = nil
    end
    set_goflags(tags)
    -- The running server was started with the old tags; buildFlags overrides
    -- them, and without buildFlags gopls goes back to its startup GOFLAGS
    for _, client in ipairs(clients) do
        client.settings.gopls.buildFlags = tags and { "-tags=" .. tags } or nil
        client:notify("workspace/didChangeConfiguration", { settings = client.settings })
    end
    vim.notify(tags and ("Go build tags: %s (saved in %s)"):format(tags, path(root))
        or "Go build tags cleared")
end, { nargs = "?", desc = "Set and save the project's Go build tags" })

return M
