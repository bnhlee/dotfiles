-- Statusline: file and flags, then the git branch with gitsigns' change counts;
-- on the right LSP progress, diagnostics, attached servers, filetype and
-- position. Each %{%...%} item is evaluated for the window being drawn.
local M = {}

-- Text from outside (branch, server names) with % escaped for the statusline
local function escape(s)
    return (s:gsub("%%", "%%%%"))
end

function M.git()
    local head = vim.b.gitsigns_head
    if not head or head == "" then
        return ""
    end
    local changes = vim.b.gitsigns_status or ""
    return escape(" " .. head .. (changes ~= "" and " " .. changes or ""))
end

function M.right()
    local parts = {}
    -- Like the default statusline, LSP progress only in the current window
    if vim.api.nvim_get_current_win() == tonumber(vim.g.actual_curwin or -1) then
        table.insert(parts, vim.ui.progress_status())
    end
    table.insert(parts, vim.diagnostic.status())
    local names = vim.tbl_map(function(client)
        return client.name
    end, vim.lsp.get_clients({ bufnr = 0 }))
    if #names > 0 then
        table.insert(parts, escape(table.concat(names, ",")))
    end
    table.insert(parts, vim.bo.filetype)
    return table.concat(
        vim.tbl_filter(function(part)
            return part ~= ""
        end, parts),
        "  "
    )
end

vim.opt.statusline = "%<%f %h%w%m%r %{%v:lua.require'config.statusline'.git()%}"
    .. "%=%{%v:lua.require'config.statusline'.right()%}  %-12.(%l,%c%V%) %P"

-- Diagnostics and progress already redraw the statusline; git changes and
-- servers starting or stopping don't
local group = vim.api.nvim_create_augroup("statusline", { clear = true })
local function redraw()
    -- Scheduled: a detaching server is still listed while LspDetach runs
    vim.schedule(function()
        vim.cmd.redrawstatus({ bang = true })
    end)
end
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, { group = group, callback = redraw })
vim.api.nvim_create_autocmd("User", { group = group, pattern = "GitSignsUpdate", callback = redraw })

return M
