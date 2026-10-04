return {
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.work", "go.mod", ".git" },
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
