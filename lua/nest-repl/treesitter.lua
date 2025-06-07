local TSWrapper = {}

---@class TSWrapper
---@field parser TSParser
---@field tree TSTree
---@field root TSNode

function TSWrapper:new()
	local obj = {
		parser = nil,
		tree = nil,
		root = nil,
	}

	setmetatable(obj, self)
	self.__index = self

	obj:init_treesitter()

	return obj
end

function TSWrapper:init_treesitter()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if not filename:match("%.ts$") and not filename:match("%.js$") then
		vim.notify("Not a TypeScript/JavaScript file", vim.log.levels.ERROR)
		return nil
	end

	local ok, parser = pcall(vim.treesitter.get_parser, 0, "typescript")
	if not ok or not parser then
		vim.notify(
			"TypeScript or Javascript parser not available. Install with :TSInstall typescript or :TSInstall javascript",
			vim.log.levels.ERROR
		)
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		vim.notify("Can't parse the buffer with treesitter", vim.log.levels.ERROR)
		return nil
	end

	local root = tree:root()
	if not root then
		vim.notify("Can't can't find tree root with treesitter", vim.log.levels.ERROR)
		return nil
	end

	self.parser = parser
	self.tree = tree
	self.root = root
end

---@alias Parameter {name: string, type: string, optional: boolean}
---@alias MethodInfo {name: string, args: Parameter[], line: integer}

---@param self TSWrapper
---@param start_line number
---@param end_line number
function TSWrapper:get_methods_with_args(start_line, end_line)
	-- Convert to 0-based indexing
	local start_row = start_line - 1
	local end_row = end_line - 1

	local query_string = [[
    (method_definition
      name: (property_identifier) @name
      parameters: (formal_parameters) @params) @method
    (public_field_definition
      name: (property_identifier) @name
      value: (arrow_function
        parameters: (formal_parameters) @params) @method)
  ]]

	local ok_query, query = pcall(vim.treesitter.query.parse, self.parser:lang(), query_string)
	if not ok_query or not query then
		return {}
	end

	local methods = {}

	for id, node in query:iter_captures(self.root, 0, start_row, end_row) do
		local capture = query.captures[id]

		-- Only process method nodes first to establish context
		if capture == "method" then
			local method_name_node
			local params_node

			-- Find the name and params for this method
			for cid, cnode in query:iter_captures(node, 0) do
				local ccap = query.captures[cid]
				if ccap == "name" then
					method_name_node = cnode
				elseif ccap == "params" then
					params_node = cnode
				end
			end

			if method_name_node and node:range() then
				local range = { node:range() }
				local method_name = vim.treesitter.get_node_text(method_name_node, 0)
				local args = {}

				-- Process parameters if they exist
				if params_node then
					for param in params_node:iter_children() do
						local param_type = param:type()
						if param_type == "required_parameter" or param_type == "optional_parameter" then
							local param_info = {
								name = "",
								type = "any",
								optional = param_type == "optional_parameter",
							}

							for child in param:iter_children() do
								local child_type = child:type()
								if child_type == "identifier" then
									param_info.name = vim.treesitter.get_node_text(child, 0)
								elseif child_type == "type_annotation" then
									param_info.type = vim.treesitter.get_node_text(child, 0):gsub("^:%s*", "")
								end
							end

							table.insert(args, param_info)
						end
					end
				end

				table.insert(methods, {
					name = method_name,
					args = args,
					line = range[1] + 1, -- Convert to 1-based
				})
			end
		end
	end

	return methods
end

---@param self TSWrapper
function TSWrapper:get_class_names()
	local query_string = [[
    (class_declaration name: (type_identifier) @class_name)
  ]]

	local ok_query, query = pcall(vim.treesitter.query.parse, self.parser:lang(), query_string)
	if not ok_query or not query then
		return {}
	end

	local class_names = {}

	for id, node, _ in query:iter_captures(self.root, 0) do
		local capture = query.captures[id]

		if capture == "class_name" then
			local name = vim.treesitter.get_node_text(node, 0)
			table.insert(class_names, name)
		end
	end

	return class_names
end

---@param self TSWrapper
---@return number | nil
---@return number | nil
function TSWrapper:find_current_method()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- Tree-sitter is 0-indexed

	local query_string = [[
        (function_declaration) @function.outer
        (method_definition) @function.outer
        (arrow_function) @function.outer
        (function_expression) @function.outer
        (call_expression
            (function_expression) @function.outer
        )
        (call_expression
            (arrow_function) @function.outer
        )
    ]]

	local query = vim.treesitter.query.parse(self.parser:lang(), query_string)
	if not query then
		print("Failed to parse Tree-sitter query.")
		return nil, nil
	end

	local best_match_start = nil
	local best_match_end = nil

	-- Iterate through all matches in the tree
	for _, node in query:iter_captures(self.root, bufnr) do
		local start_row, _, _ = node:start()
		local end_row, _, _ = node:end_()

		-- Check if the cursor is within the range of this function/method node
		if cursor_line >= start_row and cursor_line <= end_row then
			-- If multiple functions are nested, we want the "closest" or "innermost" one.
			-- Tree-sitter's `iter_matches` usually returns nodes in a depth-first manner,
			-- so the last matching node that contains the cursor will be the innermost.
			-- However, to be explicit, we can keep track of the smallest range that contains the cursor.
			if best_match_start == nil or (start_row >= best_match_start and end_row <= best_match_end) then
				best_match_start = start_row
				best_match_end = end_row
			end
		end
	end

	if best_match_start ~= nil then
		-- Convert 0-indexed Tree-sitter rows to 1-indexed Neovim lines
		return best_match_start + 1, best_match_end + 1
	end

	return nil, nil
end

---@param self TSWrapper
function TSWrapper:has_arguments(func_node, bufnr)
	local query = vim.treesitter.query.parse(self.parser:lang()([[
      (function_declaration
        parameters: (formal_parameters) @params)
      (function_expression
        parameters: (formal_parameters) @params)
      (arrow_function
        parameters: (formal_parameters) @params)
    ]]))

	for _, _ in query:iter_captures(func_node, bufnr) do
		return true
	end
	return false
end

return TSWrapper
