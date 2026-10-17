return {
    cmd = { "gopls" },
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
