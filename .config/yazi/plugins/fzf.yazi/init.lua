local function splitAndGetFirst(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local sepStart, sepEnd = string.find(inputstr, sep)
    if sepStart then
        return string.sub(inputstr, 1, sepStart - 1)
    end
    return inputstr
end

local state = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function fail(s, ...) ya.notify { title = "Fzf", content = string.format(s, ...), timeout = 5, level = "error" } end

local function entry(_, args)
	local _permit = ya.hide()
	local cwd = state()
	local shell_value = os.getenv("SHELL"):match(".*/(.*)")
	local cmd_args = ""

		-- cmd_args = [[fzf --preview='bat --color=always {1}']]
    cmd_args = [[find -L . \
      \( -name '.git' \
      -o -name 'flake-inputs' \
      -o -name '.ICAClient' \
      -o -name '.cache' \
      -o -name '.local' \
      -o -name '.config' \
      -o -name '.mill' \
      -o -name '.metals' \
      -o -name '.android' \
      -o -name '.bloop' \
      -o -name '.icons' \
      -o -name '.ivy2' \
      -o -name '.java' \
      -o -name '.mozilla' \
      -o -name '.pki' \
      -o -name '.sbt' \
      -o -name '.ssh' \
      -o -name '.steel' \
      -o -name '.smt_solvers' \
      -o -name '.tor project' \
      -o -name 'Downloads' \
      -o -name 'nixpkgs' \
      -o -name 'nixpkgs_mine' \
      -o -name '.nix-defexpr' \
      -o -name '.nix-profile' \
      -o -path './go/pkg' \
      -o -name '.vscode' \
      -o -name '__pycache__' \
      -o -name '.github' \
      -o -name 'conda' \
      -o -name 'venv' \
      -o -name '.venv' \
      -o -name '.tldrc' \
      -o -name 'node_modules' \
      -o -path './.local' \
      -o -name '.direnv' \) \
      -prune -o -type d -print |
      fzf ]]

	local child, err =
		Command(shell_value):args({"-c", cmd_args}):cwd(cwd):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()

	if not child then
		return fail("Spawn `rfzf` failed with error code %s. Do you have it installed?", err)
	end

	local output, err = child:wait_with_output()
	if not output then
		return fail("Cannot read `fzf` output, error code %s", err)
	elseif not output.status.success and output.status.code ~= 130 then
		return fail("`fzf` exited with error code %s", output.status.code)
	end

	local target = output.stdout:gsub("\n$", "")

    local file_url = splitAndGetFirst(target,":")

	if file_url ~= "" then
		ya.manager_emit(file_url:match("[/\\]$") and "cd" or "reveal", { file_url })
	end
end

return { entry = entry }
