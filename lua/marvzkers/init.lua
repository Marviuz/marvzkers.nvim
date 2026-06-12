local utils = require("marvzkers._utils")

local M = {}

M._context = {
	_marker_window_id = nil,
	_marker_window_bufnr = nil,
	_marker_window_path_ctx = nil,
}

---@type Marker.Options
local options = {
	save_path = vim.fn.getcwd() .. "/.marvzplugdb",
	save_file = "markers.json",
	colors = {
		inactive = "lualine_a_inactive",
		active_row = "lualine_b_normal",
		active_row_col = "lualine_a_normal",
	},
}

---@param user_options Marker.Options?
M.setup = function(user_options)
	options = vim.tbl_deep_extend("force", options, user_options or {})
end

---@type Marker.Api
M.api = {
	---@return Marker.Entry[]
	markers = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local buf_rel_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
		local db_path = vim.fs.joinpath(options.save_path, options.save_file)
		local data = utils.load(db_path)
		local markers = data and data[buf_rel_path] or {}

		utils.create_sign(bufnr, markers)

		return markers
	end,
}

---@return nil
M.mark = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local buf_rel_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
	local db_path = vim.fs.joinpath(options.save_path, options.save_file)

	local row = cursor[1]
	local col = cursor[2]

	utils.save({
		path = buf_rel_path,
		cursor = {
			row = row,
			col = col,
		},
	}, db_path)

	vim.notify("Marked " .. row .. ":" .. col .. " " .. vim.fn.fnamemodify(buf_rel_path, ":t"))
end

---@param params Marker.JumpIndex | Marker.JumpCoordinates
M.jump = function(params)
	if not params.index then
		vim.api.nvim_win_set_cursor(0, { params.row, params.col })
		vim.cmd("normal! zz")
		return
	end

	local markers = M.api.markers()

	if not markers or #markers == 0 then
		vim.notify("No markers found", vim.log.levels.WARN)
		return
	end

	local marker = markers[params.index]

	vim.api.nvim_win_set_cursor(0, { marker.cursor.row, marker.cursor.col })
	vim.cmd("normal! zz")
end

---@return string
M.lualine = function()
	local result = {}
	local markers = M.api.markers()

	if not markers or #markers == 0 then
		return ""
	end

	for index, marker in ipairs(markers) do
		local cursor = vim.api.nvim_win_get_cursor(0)
		local color = options.colors.inactive

		if cursor[1] == marker.cursor.row then
			color = options.colors.active_row

			if cursor[2] == marker.cursor.col then
				color = options.colors.active_row_col
			end
		end

		local label = marker.note and "[" .. index .. "] " .. marker.note or "[" .. index .. "]"
		table.insert(result, utils.wrap(color, label))
	end

	return table.concat(result)
end

---@param callback fun(bufnr: number)?
---@return nil
M.toggle_marker_window = function(callback)
	if M._context._marker_window_id and vim.api.nvim_win_is_valid(M._context._marker_window_id) then
		vim.api.nvim_win_close(M._context._marker_window_id, true)
		M._context._marker_window_id = nil
		M._context._marker_window_bufnr = nil
		M._context._marker_window_path_ctx = nil
		return
	end

	-- Set list items first before creating the window
	-- Otherwise, we will lose buffer context
	local markers = M.api.markers()

  local buf_rel_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
	M._context._marker_window_path_ctx = buf_rel_path

	local win_id, bufnr = utils.create_window()

	M._context._marker_window_id = win_id
	M._context._marker_window_bufnr = bufnr

	local contents = {}

	for _, marker in ipairs(markers) do
		local note = marker.note and " " .. marker.note or ""
		table.insert(contents, marker.cursor.row .. ":" .. marker.cursor.col .. note)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)

	if callback then
		callback(bufnr)
	end
end

---@return nil
M.save_window = function()
	local lines = vim.api.nvim_buf_get_lines(M._context._marker_window_bufnr, 0, -1, false)
	local db_path = vim.fs.joinpath(options.save_path, options.save_file)

	local cursors = {}

	for _, line in ipairs(lines) do
		local cursor = utils.parse_window_line(line)
		if cursor then
			table.insert(cursors, {
				row = cursor.row,
				col = cursor.col,
				note = cursor.note,
			})
		end
	end

	utils.replace_cursors({
		path = M._context._marker_window_path_ctx,
		cursors = cursors,
	}, db_path)

	M.toggle_marker_window()
end

---@return nil
M.select = function()
	local line = vim.api.nvim_get_current_line()
	local cursor = utils.parse_window_line(line)
	if not cursor then
		return
	end

	-- Close the window first to not make it out-of-bounds
	M.toggle_marker_window()
	M.jump(cursor)
end

return M
