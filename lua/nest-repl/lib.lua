local M = {}

-- State to track the REPL terminal
local state = {
	repl_terminal = nil,
	repl_bufnr = nil,
	repl_job_id = nil,
}

---@param method MethodInfo
---@param class_name string
---@param method_name string
---@param on_success fun(args: string[])
local function ask_for_arguments(method, class_name, method_name, on_success)
	local args = {}
	local current_arg_index = 1

	local function ask_for_arg()
		if current_arg_index > #method.args then
			on_success(args)
			return
		end

		local arg = method.args[current_arg_index]
		vim.ui.input({
			prompt = string.format("%s: %s ", arg.name, arg.type),
		}, function(input)
			if input then
				table.insert(args, input)
				current_arg_index = current_arg_index + 1
				ask_for_arg()
			end
		end)
	end

	ask_for_arg()
end

-- Find the root of the NestJS project
function M.find_nest_root()
	local current_dir = vim.fn.expand("%:p:h")
	local nest_config = vim.fn.findfile("nest-cli.json", current_dir .. ";")

	if nest_config == "" then
		return nil
	end

	return vim.fn.fnamemodify(nest_config, ":h")
end

-- Start or focus the REPL terminal
---@param config Config
function M.start_repl(config)
	local project_root = M.find_nest_root()
	if not project_root then
		vim.notify("Not in a NestJS project directory", vim.log.levels.ERROR)
		return
	end

	-- If terminal exists, just focus it
	if state.repl_terminal and vim.api.nvim_win_is_valid(state.repl_terminal) then
		vim.api.nvim_set_current_win(state.repl_terminal)
		return
	end

	-- Create a new terminal based on position config
	if config.terminal_position == "left" then
		vim.cmd("leftabove vsplit")
	else
		vim.cmd("rightbelow vsplit")
	end

	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_win_set_width(win, config.terminal_width) -- Set terminal width

	-- Start the REPL
	local job_id = vim.fn.termopen(string.format("cd %s && %s", project_root, config.repl_command), {
		on_exit = function()
			state.repl_terminal = nil
			state.repl_bufnr = nil
			state.repl_job_id = nil
		end,
	})

	-- Store terminal info
	state.repl_terminal = win
	state.repl_bufnr = buf
	state.repl_job_id = job_id

	-- Set terminal options
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "terminal")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")

	-- Add keymaps
	vim.keymap.set("t", "<C-w>q", function()
		vim.api.nvim_win_close(win, true)
		state.repl_terminal = nil
		state.repl_bufnr = nil
		state.repl_job_id = nil
	end, { buffer = buf, silent = true })
end

-- Send command to REPL terminal
function M.send_to_repl(cmd)
	if not state.repl_terminal or not vim.api.nvim_win_is_valid(state.repl_terminal) then
		vim.notify("REPL terminal not found. Start it with :NestReplStart", vim.log.levels.ERROR)
		return
	end

	-- Switch to terminal window
	local current_win = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(state.repl_terminal)

	-- Send the command using chansend
	vim.fn.chansend(state.repl_job_id, cmd .. "\n")

	-- Switch back to previous window
	vim.api.nvim_set_current_win(current_win)
end

---@param ts_wrapper table
---@param start_line number
---@param end_line number
function M.load_methods_to_repl(ts_wrapper, start_line, end_line)
	local class_names = ts_wrapper:get_class_names()

	if #class_names == 0 then
		vim.notify("Could not find class name in file", vim.log.levels.ERROR)
		return
	end

	-- NOTE: For now it's ok to get the first class because we assume one per file, but it would be
	-- cool to add a picker to handle multiple classes or figure out a way to get the closest one.
	local class_name = class_names[1]

	---@type MethodInfo[]
	local methods = ts_wrapper:get_methods_with_args(start_line, end_line)

	if #methods > 1 then
		vim.notify("Found more than one method inside the selection", vim.log.levels.WARN)
		return
	end

	local method = methods[1]

	-- Extract method name
	local method_name = method.name
	if not method_name then
		vim.notify("Could not extract method name from selection", vim.log.levels.ERROR)
		return
	end

	if #method.args > 0 then
		ask_for_arguments(method, class_name, method_name, function(args)
			M.send_to_repl(string.format("await $(%s).%s(%s)", class_name, method_name, table.concat(args, ", ")))
		end)
		return
	end

	-- Send method to REPL with correct syntax
	M.send_to_repl(string.format("await $(%s).%s()", class_name, method_name))
end

---@param ts_wrapper table
---@param start_line number
---@param end_line number
function M.load_method_to_variable(ts_wrapper, start_line, end_line)
	local class_names = ts_wrapper:get_class_names()

	if #class_names == 0 then
		vim.notify("Could not find class name in file", vim.log.levels.ERROR)
		return
	end

	-- NOTE: For now it's ok to get the first class because we assume one per file, but it would be
	-- cool to add a picker to handle multiple classes or figure out a way to get the closest one.
	local class_name = class_names[1]

	---@type MethodInfo[]
	local methods = ts_wrapper:get_methods_with_args(start_line, end_line)

	if #methods > 1 then
		vim.notify("Found more than one method inside the selection", vim.log.levels.WARN)
		return
	end

	local method = methods[1]

	local method_name = method.name
	if not method_name then
		vim.notify("Could not extract method name from selection", vim.log.levels.ERROR)
		return
	end

	if #method.args > 0 then
		ask_for_arguments(method, class_name, method_name, function(args)
			M.send_to_repl(
				string.format(
					"let %s = await $(%s).%s(%s)",
					method_name,
					class_name,
					method_name,
					vim.fn.join(args, ", ")
				)
			)
		end)
		return
	end

	-- Send method to REPL with variable assignment
	M.send_to_repl(string.format("let %s = await $(%s).%s()", method_name, class_name, method_name))
end

return M
