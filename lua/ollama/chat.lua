local M = {}

M._chat_popup = { win = nil, buf = nil, close = nil }

---@return boolean # true if popup was closed
M._chat_popup_close = function()
	if M._chat_popup and M._chat_popup.win and vim.api.nvim_win_is_valid(M._chat_popup.win) then
		M._chat_popup.close()
		M._chat_popup = nil
		return true
	end
	return false
end

M.new = function(config)
	-- if popup chat is open, close it and start a new one
	if M._chat_popup_close() then
		config.args = config.args or ""
		if config.args == "" then
			config.args = "popup"
		end
		return M.cmd.ChatNew(config)
	end

	-- prepare filename
	local time = os.date("%Y-%m-%d.%H-%M-%S")
	local stamp = tostring(math.floor(vim.loop.hrtime() / 1000000) % 1000)
	-- make sure stamp is 3 digits
	while #stamp < 3 do
		stamp = "0" .. stamp
	end
	time = time .. "." .. stamp
	local filename = M.config.chat_dir .. "/" .. time .. ".md"

	-- encode as json if model is a table
	local model = config.model
	if type(model) == "table" then
		model = vim.json.encode(model)
	end

	-- display system prompt as single line with escaped newlines
	local system_prompt = system_prompt or M.config.chat_system_prompt
	system_prompt = system_prompt:gsub("\n", "\\n")

	local template = string.format(
		M.chat_template,
		model,
		string.match(filename, "([^/]+)$"),
		system_prompt,
		M.config.chat_user_prefix,
		M.config.chat_shortcut_respond.shortcut,
		M.config.cmd_prefix,
		M.config.chat_shortcut_delete.shortcut,
		M.config.cmd_prefix,
		M.config.chat_shortcut_new.shortcut,
		M.config.cmd_prefix,
		M.config.chat_user_prefix
	)
	-- escape underscores (for markdown)
	template = template:gsub("_", "\\_")

	if config.range == 2 then
		-- get current buffer
		local buf = vim.api.nvim_get_current_buf()

		-- get range lines
		local lines = vim.api.nvim_buf_get_lines(buf, config.line1 - 1, config.line2, false)
		local selection = table.concat(lines, "\n")

		if selection ~= "" then
			local filetype = M._H.get_filetype(buf)
			local fname = vim.api.nvim_buf_get_name(buf)
			local rendered = M.template_render(M.config.template_selection, "", selection, filetype, fname)
			template = template .. "\n" .. rendered
		end
	end

	-- strip leading and trailing newlines
	template = template:gsub("^%s*(.-)%s*$", "%1") .. "\n"

	-- create chat file
	vim.fn.writefile(vim.split(template, "\n"), filename)

	local target = M.resolve_chat_target(config)
	-- open and configure chat file
	return M.open_chat(filename, target)
end

return M
