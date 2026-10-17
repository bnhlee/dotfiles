-- A short list of files per project, each one keypress away. Lists are kept
-- per working directory (harpoon's default), so start nvim in the project
local harpoon = require("harpoon")

local function list()
    return harpoon:list()
end

harpoon:setup({
    settings = {
        save_on_toggle = true,
    },
})

local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

-- Step through the list from the current file's slot (harpoon's own next/prev
-- keep a separate position that slot jumps don't move). Wraps around and skips
-- emptied slots; from a file not in the list, starts at the first or last
local function cycle(step)
    local l = list()
    local n = l:length()
    if n == 0 then
        return
    end
    local _, i = l:get_by_value(l.config.create_list_item(l.config).value)
    i = i or (step > 0 and 0 or n + 1)
    for _ = 1, n do
        i = (i + step - 1) % n + 1
        if l.items[i] then
            return l:select(i)
        end
    end
end

map("<leader>a", function() list():add() end, "Add file to harpoon")
-- The list is a normal buffer: reorder lines, dd to remove, then close it
map("<leader>e", function() harpoon.ui:toggle_quick_menu(list()) end, "Harpoon list")

-- Alt + home row, like Alt-1..9 for tmux windows and Alt-hjkl for panes
for i, k in ipairs({ "a", "s", "d", "f" }) do
    map("<M-" .. k .. ">", function() list():select(i) end, "Harpoon file " .. i)
end
-- In normal mode these only repeated j/k
map("<C-n>", function() cycle(1) end, "Next harpoon file")
map("<C-p>", function() cycle(-1) end, "Previous harpoon file")
