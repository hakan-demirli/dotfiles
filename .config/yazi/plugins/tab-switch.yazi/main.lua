--- @sync entry

local function entry(_, job)
	local target = tonumber(job.args[1]) or 0
	local num_tabs = #cx.tabs

	while num_tabs <= target do
		ya.emit("tab_create", { current = true })
		num_tabs = num_tabs + 1
	end

	ya.emit("tab_switch", { target })
end

return { entry = entry }
