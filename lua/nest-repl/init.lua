local treesitter = require("nest-repl.treesitter")
local lib = require("nest-repl.lib")

local M = {}

---@alias Keybindings {start_repl: string, load_method: string, load_method_to_var: string}
---@alias Config {repl_command: string, debug: boolean, terminal_width: number, terminal_position: 'right' | 'left', keybindings: Keybindings}

-- Configuration
---@type Config
local config = {
	repl_command = "npx nest repl",
	debug = false,
	terminal_width = 80, -- Width of the terminal split
	terminal_position = "right", -- 'left' or 'right'
	keybindings = {
		start_repl = "<localleader>snr",
		load_method = "<localleader>em",
		load_method_to_var = "<localleader>etv",
	},
}

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	local start_repl = function()
		lib.start_repl(config)
	end

	local load_method = function()
		local TSWrapper = treesitter:new()

		if not TSWrapper then
			return
		end

		local start_line = nil
		local end_line = nil
		if string.find(vim.fn.mode(), "[vV\x16]") then
			start_line = vim.fn.line("v")
			end_line = vim.fn.line(".")
		end

		if vim.fn.mode() == "n" then
			start_line, end_line = TSWrapper:find_current_method()
		end

		if start_line and end_line then
			lib.load_methods_to_repl(TSWrapper, start_line, end_line)
		end
	end

	local load_method_to_variable = function()
		local TSWrapper = treesitter:new()

		if not TSWrapper then
			return
		end

		local start_line = nil
		local end_line = nil
		if string.find(vim.fn.mode(), "[vV\x16]") then
			start_line = vim.fn.line("v")
			end_line = vim.fn.line(".")
		end

		if vim.fn.mode() == "n" then
			start_line, end_line = TSWrapper:find_current_method()
		end

		if start_line and end_line then
			lib.load_method_to_variable(TSWrapper, start_line, end_line)
		end
	end

	-- NOTE: start repl
	vim.keymap.set("n", config.keybindings.start_repl, start_repl, { desc = "Start NestJS REPL" })
	vim.api.nvim_create_user_command("NestReplStart", start_repl, {})

	-- NOTE: load method
	vim.keymap.set({ "n", "v" }, config.keybindings.load_method, load_method, { desc = "Load method to NestJS REPL" })
	vim.api.nvim_create_user_command("NestReplLoad", function(cmd_opts)
		if not cmd_opts.range then
			vim.notify("Please select a method in visual mode", vim.log.levels.WARN)
			return
		end

		load_method()
	end, { range = true })

	-- NOTE: load method to var
	vim.keymap.set(
		{ "n", "v" },
		config.keybindings.load_method_to_var,
		load_method_to_variable,
		{ desc = "Load selected method to variable in NestJS REPL" }
	)
end

return M
