local M = {}

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		return ya.preview_widget(job, err)
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	local _, err = ya.image_show(cache, job.area)
	ya.preview_widget(job, err)
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end

function M:preload(job)
	local percent = 5 + job.skip
	if percent > 95 then
		ya.emit("peek", { 90, only_if = job.file.url, upper_bound = true })
		return false, nil
	end

	local cache = ya.file_cache(job)
	if not cache then
		return true, nil
	end

	local cha = fs.cha(cache)
	if cha and cha.len > 0 then
		return true, nil
	end

	local child, err = Command("ffmpegthumbnailer"):arg({
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
		return true, Err("spawn `ffmpegthumbnailer` command returns " .. tostring(err))
	end

	local status = child:wait()
	if status and status.success then
		return true, nil
	else
		return false, nil
	end
end

function M:spot(job) require("file"):spot(job) end

return M
