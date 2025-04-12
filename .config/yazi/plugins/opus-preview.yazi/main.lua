local M = {}

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		return
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, job.area)
	ya.preview_widgets(job, {})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.mgr_emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end

function M:preload(job)
	local percent = 5 + job.skip
	if percent > 95 then
		ya.mgr_emit("peek", { 90, only_if = job.file.url, upper_bound = true })
		return false, nil -- Previously 2, continue
	end

	local cache = ya.file_cache(job)
	if not cache then
		return true, nil -- Previously 1, don't continue
	end

	local cha = fs.cha(cache)
	if cha and cha.len > 0 then
		return true, nil -- Previously 1, don't continue
	end

	local child, err = Command("ffmpegthumbnailer"):args({
		"-q",
		"6",
		"-c",
		"jpeg",
		"-i",
		tostring(job.file.url),
		"-o",
		tostring(cache),
		"-t",
		tostring(percent),
		"-s",
		tostring(rt.preview.max_width),
	}):spawn()

	if not child then
		ya.err("spawn `ffmpegthumbnailer` command returns " .. tostring(err))
		return true, Err("spawn `ffmpegthumbnailer` command returns " .. tostring(err)) -- Convert the message to an error
	end

	local status = child:wait()
	if status and status.success then
		return true, nil -- Previously 1, don't continue
	else
		return false, nil -- Previously 2, continue
	end
end

function M:spot(job) require("file"):spot(job) end

return M
