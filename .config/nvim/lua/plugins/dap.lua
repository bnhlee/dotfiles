local dap = require("dap")
local dap_view = require("dap-view")

require("dap-go").setup()

dap_view.setup({})
-- Show the debugger panel while a session is running
local function open() dap_view.open() end
local function close() dap_view.close() end
dap.listeners.before.attach["dap-view"] = open
dap.listeners.before.launch["dap-view"] = open
dap.listeners.before.event_terminated["dap-view"] = close
dap.listeners.before.event_exited["dap-view"] = close

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<F5>", dap.continue, "Debug: start/continue")
map("<F10>", dap.step_over, "Debug: step over")
map("<F11>", dap.step_into, "Debug: step into")
map("<F12>", dap.step_out, "Debug: step out")

map("<leader>dc", dap.continue, "Start/continue")
map("<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
map("<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Condition: "))
end, "Conditional breakpoint")
map("<leader>dC", dap.run_to_cursor, "Run to cursor")
map("<leader>dn", dap.step_over, "Step over")
map("<leader>di", dap.step_into, "Step into")
map("<leader>do", dap.step_out, "Step out")
map("<leader>dl", dap.run_last, "Rerun last session")
map("<leader>dq", dap.terminate, "Stop")
map("<leader>du", dap_view.toggle, "Toggle debugger panel")
map("<leader>de", function() require("dap.ui.widgets").hover() end, "Evaluate under cursor")
map("<leader>dt", function() require("dap-go").debug_test() end, "Debug nearest Go test")
map("<leader>dT", function() require("dap-go").debug_last_test() end, "Debug last Go test")
