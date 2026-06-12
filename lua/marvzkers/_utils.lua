local M = {}

---@param highlight_group string
---@param str string
---@return string
M.wrap = function(highlight_group, str)
	return "%#" .. highlight_group .. "# " .. str .. " %*"
end

---@param path string
---@return table|nil
M.load = function(path)
	if not vim.uv.fs_stat(path) then
		return nil
	end

	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return nil
	end

	local ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	return ok and decoded or nil
end

---@param marker_data Marker.Data
---@param file_path string
M.save = function(marker_data, file_path)
	local data = M.load(file_path) or {}

	if not data[marker_data.path] then
		data[marker_data.path] = {}
	end

	table.insert(data[marker_data.path], {
		cursor = marker_data.cursor,
	})

	local dir = vim.fs.dirname(file_path)
	if not vim.uv.fs_stat(dir) then
		vim.fn.mkdir(dir, "p")
	end
	vim.fn.writefile(vim.split(vim.fn.json_encode(data), "\n"), file_path)
end

---@param replacement_data Marker.ReplacementData
---@param file_path string
M.replace_cursors = function(replacement_data, file_path)
	local data = M.load(file_path) or {}

	data[replacement_data.path] = {}

	for _, cursor in ipairs(replacement_data.cursors) do
		table.insert(data[replacement_data.path], {
			cursor = { row = cursor.row, col = cursor.col },
			note = cursor.note,
		})
	end

	vim.fn.writefile(vim.split(vim.fn.json_encode(data), "\n"), file_path)
end

---@return number, number
M.create_window = function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local width = 60
	local height = 10

	vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

	local win_id = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		title = "Markers",
		title_pos = "center",
		row = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "single",
	})

	-- Prevent jumps from the buffer doens't change accidentally
	vim.api.nvim_set_option_value("winfixbuf", true, { win = win_id })
	vim.api.nvim_set_option_value("number", true, { win = win_id })

	-- Close the window when out of focus so we don't accidentally
	-- leave it open annoyingly
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = bufnr,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end,
	})

	return win_id, bufnr
end

---@param line string
---@return Marker.Cursor?
M.parse_window_line = function(line)
	if #line == 0 then
		return nil
	end

	local row, col, note = line:match("(%d+):(%d+)%s*(.*)")
	row = tonumber(row)
	col = tonumber(col)

	if #note == 0 then
		note = nil
	end

	return { row = row, col = col, note = note }
end

---@param bufnr number
---@param markers Marker.Entry[]
---@return nil
M.create_sign = function(bufnr, markers)
	vim.fn.sign_unplace("MarkerSignGroup", { buffer = bufnr })

	for idx, marker in ipairs(markers) do
		vim.fn.sign_define("MarkerSign" .. idx, {
			text = "m" .. idx,
			texthl = "lualine_a_normal",
		})

		vim.fn.sign_place(idx, "MarkerSignGroup", "MarkerSign" .. idx, bufnr, { lnum = marker.cursor.row })
	end
end
return M
