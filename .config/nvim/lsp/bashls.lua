-- Installed by dotfiles-bootstrap. Runs shellcheck on the buffer when it's
-- installed, and formats (gq) with shfmt when that is.
return {
    cmd = { "bash-language-server", "start" },
    filetypes = { "bash", "sh" },
    root_markers = { ".git" },
}
