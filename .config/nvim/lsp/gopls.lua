return {
    -- Each nvim runs a small forwarder to one shared gopls daemon (started on
    -- demand, exits a minute after the last nvim disconnects), so several
    -- sessions in tmux panes don't each load the same packages. The forwarder
    -- passes along its go env, GOFLAGS included, for each session.
    -- The forwarder exits with code 2 even when nvim stops it (:lsp restart),
    -- which nvim warns about; that exit is only reported when it's unexpected
    cmd = function(dispatchers, config)
        local stopping = false
        local rpc = vim.lsp.rpc.start({ "gopls", "-remote=auto" }, vim.tbl_extend("force", dispatchers, {
            on_exit = function(code, signal)
                dispatchers.on_exit((stopping and code == 2) and 0 or code, signal)
            end,
        }), { cwd = config.cmd_cwd, env = config.cmd_env, detached = config.detached })
        local request = rpc.request
        rpc.request = function(method, ...)
            stopping = stopping or method == "shutdown"
            return request(method, ...)
        end
        return rpc
    end,
    -- Read by config/lsp.lua to only enable the server when it's installed
    executable = "gopls",
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.work", "go.mod", ".git" },
    -- Build tags saved for the project with :GoTags (config/gotags.lua). gopls
    -- itself always gets nvim's startup GOFLAGS ("" for none), not one left
    -- by another project
    cmd_env = { GOFLAGS = require("config.gotags").startup_goflags or "" },
    before_init = function(params, config)
        require("config.gotags").before_init(params, config)
    end,
    settings = {
        gopls = {
            staticcheck = true,
            analyses = {
                -- Value assigned and then overwritten before being read, e.g. an
                -- err that's never checked before the next call reassigns it
                SA4006 = true,
            },
            -- Shown when inlay hints are toggled on (<leader>th)
            hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
            },
        },
    },
}
