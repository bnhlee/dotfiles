-- PowerShellEditorServices, installed by dotfiles-bootstrap, run by the
-- system's pwsh (config/lsp.lua skips it when pwsh isn't installed).
-- Also runs PSScriptAnalyzer for diagnostics.
local bundle = vim.fn.expand("~/.local/share/lsp/pses")
local logs = vim.fn.stdpath("log")

return {
    cmd = {
        "pwsh", "-NoLogo", "-NoProfile", "-Command",
        ("& '%s/PowerShellEditorServices/Start-EditorServices.ps1'"):format(bundle)
            .. (" -BundledModulesPath '%s'"):format(bundle)
            .. (" -LogPath '%s/powershell_es.log'"):format(logs)
            .. (" -SessionDetailsPath '%s/powershell_es.session.json'"):format(logs)
            .. " -FeatureFlags @() -AdditionalModules @()"
            .. " -HostName nvim -HostProfileId 0 -HostVersion 1.0.0"
            .. " -Stdio -LogLevel Normal",
    },
    filetypes = { "ps1" },
    root_markers = { "PSScriptAnalyzerSettings.psd1", ".git" },
    -- Read by config/lsp.lua to only enable the server when it's installed
    bundle = bundle,
}
