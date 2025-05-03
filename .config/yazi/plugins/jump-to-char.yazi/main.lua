local AVAILABLE_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local CASE_SENSITIVE = false

local changed = ya.sync(function(st, new)
	local b = st.last ~= new
	st.last = new
	return b
end)

return {
	entry = function()
		local cands = {}
		for i = 1, #AVAILABLE_CHARS do
			cands[#cands + 1] = { on = AVAILABLE_CHARS:sub(i, i) }
		end

		local idx = ya.which { cands = cands, silent = true }
		if not idx then
			return
		end

		local selected_char = cands[idx].on
		local search_pattern

		if CASE_SENSITIVE then
			search_pattern = "^" .. selected_char
		else
			local lower = selected_char:lower()
			local upper = selected_char:upper()

			if lower ~= upper then
				search_pattern = "^[" .. lower .. upper .. "]"
			else
				search_pattern = "^" .. selected_char
			end
		end

		if changed(selected_char) then
			ya.manager_emit("find_do", { search_pattern })
		else
			ya.manager_emit("find_arrow", {})
		end
	end,
}
