local WINDOWS = ya.target_family() == "windows"

local CODES = {
	unknown = 100,
	excluded = 99,
	ignored = 6,
	untracked = 5,
	modified = 4,
	added = 3,
	deleted = 2,
	updated = 1,
	clean = 0,
}

local PATTERNS = {
	{ "!$", CODES.ignored },
	{ "?$", CODES.untracked },
	{ "[MT]", CODES.modified },
	{ "[AC]", CODES.added },
	{ "D", CODES.deleted },
	{ "U", CODES.updated },
	{ "[AD][AD]", CODES.updated },
}

local function match(line)
	local signs = line:sub(1, 2)
	for _, p in ipairs(PATTERNS) do
		local path, pattern, code = nil, p[1], p[2]
		if signs:find(pattern) then
			path = line:sub(4, 4) == '"' and line:sub(5, -2) or line:sub(4)
			path = WINDOWS and path:gsub("/", "\\") or path
		end
		if not path then
		elseif path:find("[/\\]$") then
			return code == CODES.ignored and CODES.excluded or code, path:sub(1, -2)
		else
			return code, path
		end
	end
end

local function root(cwd)
	local is_worktree = function(url)
		local file, head = io.open(tostring(url)), nil
		if file then
			head = file:read(8)
			file:close()
		end
		return head == "gitdir: "
	end

	repeat
		local next = cwd:join(".git")
		local cha = fs.cha(next)
		if cha and (cha.is_dir or is_worktree(next)) then
			return tostring(cwd)
		end
		cwd = cwd.parent
	until not cwd
end

local function bubble_up(changed)
	local new, empty = {}, Url("")
	for path, code in pairs(changed) do
		if code ~= CODES.ignored then
			local url = Url(path).parent
			while url and url ~= empty do
				local s = tostring(url)
				new[s] = (new[s] or CODES.clean) > code and new[s] or code
				url = url.parent
			end
		end
	end
	return new
end

local function propagate_down(excluded, cwd, repo)
	local new, rel = {}, cwd:strip_prefix(repo)
	for _, path in ipairs(excluded) do
		if rel:starts_with(path) then
			new[tostring(cwd)] = CODES.excluded
		elseif cwd == repo:join(path).parent then
			new[path] = CODES.ignored
		else
		end
	end
	return new
end

local add = ya.sync(function(st, cwd, repo, changed)

	st.dirs[cwd] = repo
	st.repos[repo] = st.repos[repo] or {}
	for path, code in pairs(changed) do
		if code == CODES.clean then
			st.repos[repo][path] = nil
		elseif code == CODES.excluded then
			st.dirs[path] = CODES.excluded
		else
			st.repos[repo][path] = code
		end
	end
	ui.render()
end)

local remove = ya.sync(function(st, cwd)

	local repo = st.dirs[cwd]
	if not repo then
		return
	end

	ui.render()
	st.dirs[cwd] = nil
	if not st.repos[repo] then
		return
	end

	for _, r in pairs(st.dirs) do
		if r == repo then
			return
		end
	end
	st.repos[repo] = nil
end)

local function setup(st, opts)
	st.dirs = {}
	st.repos = {}

	opts = opts or {}
	opts.order = opts.order or 1500

	local t = th.git or {}
	local styles = {
		[CODES.unknown] = t.unknown or ui.Style(),
		[CODES.ignored] = t.ignored or ui.Style():fg("darkgray"),
		[CODES.untracked] = t.untracked or ui.Style():fg("magenta"),
		[CODES.modified] = t.modified or ui.Style():fg("yellow"),
		[CODES.added] = t.added or ui.Style():fg("green"),
		[CODES.deleted] = t.deleted or ui.Style():fg("red"),
		[CODES.updated] = t.updated or ui.Style():fg("yellow"),
		[CODES.clean] = t.clean or ui.Style(),
	}
	local signs = {
		[CODES.unknown] = t.unknown_sign or "",
		[CODES.ignored] = t.ignored_sign or " ",
		[CODES.untracked] = t.untracked_sign or "? ",
		[CODES.modified] = t.modified_sign or " ",
		[CODES.added] = t.added_sign or " ",
		[CODES.deleted] = t.deleted_sign or " ",
		[CODES.updated] = t.updated_sign or " ",
		[CODES.clean] = t.clean_sign or "",
	}

	Linemode:children_add(function(self)
		if not self._file.in_current then
			return ""
		end

		local url = self._file.url
		local repo = st.dirs[tostring(url.base or url.parent)]
		local code = CODES.unknown
		if repo then
			code = repo == CODES.excluded and CODES.ignored or st.repos[repo][tostring(url):sub(#repo + 2)] or CODES.clean
		end

		if signs[code] == "" then
			return ""
		elseif self._file.is_hovered then
			return ui.Line { " ", signs[code] }
		else
			return ui.Line { " ", ui.Span(signs[code]):style(styles[code]) }
		end
	end, opts.order)
end

local function fetch(_, job)
	local cwd = job.files[1].url.base or job.files[1].url.parent
	local repo = root(cwd)
	if not repo then
		remove(tostring(cwd))
		return true
	end

	local paths = {}
	for _, file in ipairs(job.files) do
		paths[#paths + 1] = tostring(file.url)
	end

	local output, err = Command("git")
		:cwd(tostring(cwd))
		:arg({ "--no-optional-locks", "-c", "core.quotePath=", "status", "--porcelain", "-unormal", "--no-renames", "--ignored=matching" })
		:arg(paths)
		:stdout(Command.PIPED)
		:output()
	if not output then
		return true, Err("Cannot spawn `git` command, error: %s", err)
	end

	local changed, excluded = {}, {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local code, path = match(line)
		if code == CODES.excluded then
			excluded[#excluded + 1] = path
		else
			changed[path] = code
		end
	end

	if job.files[1].cha.is_dir then
		ya.dict_merge(changed, bubble_up(changed))
	end
	ya.dict_merge(changed, propagate_down(excluded, cwd, Url(repo)))

	for _, path in ipairs(paths) do
		local s = path:sub(#repo + 2)
		changed[s] = changed[s] or CODES.clean
	end

	add(tostring(cwd), repo, changed)

	return false
end

return { setup = setup, fetch = fetch }
