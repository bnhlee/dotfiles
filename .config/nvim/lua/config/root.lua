-- Project root of the current buffer, shared by :Term and telescope
local M = {}

-- Directory of the current buffer: the folder shown in oil, or the file's folder
function M.buffer_dir()
    if vim.bo.filetype == "oil" then
        return require("oil").get_current_dir()
    end
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" and vim.uv.fs_stat(name) then
        return vim.fs.dirname(name)
    end
end

-- Git root of the buffer's directory, falling back to the directory itself,
-- then to nvim's working directory
function M.get()
    local dir = M.buffer_dir()
    return dir and (vim.fs.root(dir, ".git") or dir) or vim.fn.getcwd()
end

-- Wrap a telescope picker so it runs from the project root, wherever nvim was started
function M.in_project(picker, title)
    return function()
        local dir = M.get()
        picker({ cwd = dir, prompt_title = ("%s (%s)"):format(title, vim.fs.basename(dir)) })
    end
end

return M
