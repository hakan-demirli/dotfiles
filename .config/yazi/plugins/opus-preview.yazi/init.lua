local M = {}


function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache or self:preload(job) ~= 1 then
		return
	end

	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, job.area)
	ya.preview_widgets(job, {})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.manager_emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end

function M:preload(job)
	local percent = 5 + job.skip
	if percent > 95 then
		ya.manager_emit("peek", { 90, only_if = job.file.url, upper_bound = true })
		return 2
	end

	local cache = ya.file_cache(job)
	if not cache then
		return 1
	end

	local cha = fs.cha(cache)
	if cha and cha.len > 0 then
		return 1
	end

	local child, code = Command("ffmpegthumbnailer"):args({
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
		tostring(PREVIEW.max_width),
	}):spawn()

	if not child then
		ya.err("spawn `ffmpegthumbnailer` command returns " .. tostring(code))
		return 0
	end

	local status = child:wait()
	return status and status.success and 1 or 2
end

function M:spot(job) require("file"):spot(job) end

return M
