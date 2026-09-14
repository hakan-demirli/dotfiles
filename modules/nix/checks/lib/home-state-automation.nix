{ pkgs, self }:
pkgs.runCommand "home-state-automation"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.git
      pkgs.jq
      pkgs.util-linux
      pkgs.bash
      pkgs.coreutils
    ];
    deployScript = ../../pkgs/bin/deploy-home-secrets.sh;
    commitScript = ../../../home/common/pkgs/bin/state-autocommit.sh;
    pushScript = ../../../home/common/pkgs/bin/state-autopush.sh;
    historyFile = self.homeConfigurations."emre@shared-server-1".config.programs.bash.historyFile;
  }
  ''
    python3 - <<'PY'
    import json
    import os
    import pathlib
    import pwd
    import subprocess
    import tempfile

    git = "${pkgs.git}/bin/git"
    bash = "${pkgs.runtimeShell}"
    username = pwd.getpwuid(os.getuid()).pw_name
    branch = "hosts/fixture-host"

    def execute(args, env, success=True):
        result = subprocess.run(args, env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result.stdout.strip()

    def executable(path, body):
        path.write_text("#!${pkgs.python3}/bin/python3\n" + body)
        path.chmod(0o755)

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        tools = root / "tools"
        tools.mkdir()
        bootstrap = root / "bootstrap"
        (bootstrap / "bin").mkdir(parents=True)
        repo = root / "dotfiles"
        envelopes = repo / "secrets/identities"
        envelopes.mkdir(parents=True)
        (repo / "flake.nix").touch()
        (envelopes / "home-user-0.age.key.enc").write_text("-----BEGIN AGE ENCRYPTED FILE-----\nfixture\n")
        (envelopes / "home-user-0.age.pub").write_text("fixture-recipient\n")

        executable(tools / "hostname", 'print("fixture-host")\n')
        executable(tools / "nix", r"""
    import json, os, pathlib, sys
    target = sys.argv[-1]
    assert 'homeConfigurations."' + os.environ["FIXTURE_USER"] + '@fixture-host"' in target
    if target.endswith("homeSops.enable"):
        print(os.environ.get("ALLOW_PERSONAL", "true"))
    elif target.endswith("DOTFILES_HOST"):
        print(os.environ.get("CONFIGURED_HOST", "fixture-host"))
    elif target.endswith("home.username"):
        print(os.environ["FIXTURE_USER"])
    elif target.endswith("homeSops.identity"):
        print("user-0")
    elif target.endswith("homeSops.ageKeyFile"):
        print(os.environ["HOME"] + "/.config/sops/age/keys.txt")
    elif target.endswith("home.stateRepository"):
        print(json.dumps({"path": os.environ["STATE_PATH"], "branch": "hosts/fixture-host", "remote": os.environ["STATE_REMOTE"]}))
    elif target.endswith("homeSops.bootstrap"):
        print(os.environ["BOOTSTRAP"])
    else:
        raise AssertionError(target)
    """)
        executable(tools / "age", r"""
    import os, pathlib, sys
    with open(os.environ["EVENTS"], "a") as log: log.write("decrypt\n")
    pathlib.Path(sys.argv[sys.argv.index("--output") + 1]).write_text("fixture-identity\n")
    """)
        executable(tools / "age-keygen", 'print("fixture-recipient")\n')
        executable(bootstrap / "bin/bootstrap-home-secrets", r"""
    import os, pathlib
    home = pathlib.Path(os.environ["HOME"])
    assert (home / ".config/sops/age/keys.txt").is_file()
    for name in [".config/git/git_users", ".config/sops-nix/secrets/git_tokens", ".ssh/id_ed25519", ".ssh/id_ed25519_proton", ".ssh/id_ed25519_sf"]:
        path = home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture\n")
    with open(os.environ["EVENTS"], "a") as log: log.write("install-secrets\n")
    """)
        executable(bootstrap / "bin/git-credential-sops-readonly", 'raise SystemExit(0)\n')
        executable(tools / "git", r"""
    import os, pathlib, sys
    if "ls-remote" in sys.argv or "fetch" in sys.argv:
        assert "install-secrets" in pathlib.Path(os.environ["EVENTS"]).read_text()
        with open(os.environ["EVENTS"], "a") as log: log.write("network\n")
    os.execv("${pkgs.git}/bin/git", ["git"] + sys.argv[1:])
    """)
        executable(tools / "home-manager", r"""
    import os, pathlib, subprocess, sys
    assert sys.argv[1:3] == ["switch", "--flake"]
    assert sys.argv[3].endswith("#" + os.environ["FIXTURE_USER"] + "@fixture-host")
    state = pathlib.Path(os.environ["STATE_PATH"])
    assert (state / ".local/state/bash").is_dir()
    branch = subprocess.check_output(["${pkgs.git}/bin/git", "-C", str(state), "symbolic-ref", "--short", "HEAD"], text=True).strip()
    assert branch == "hosts/fixture-host"
    with open(os.environ["EVENTS"], "a") as log: log.write("activate\n")
    """)

        base = os.environ | {
            "PATH": str(tools) + ":" + os.environ["PATH"],
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "FIXTURE_USER": username, "BOOTSTRAP": str(bootstrap),
        }
        remote = root / "remote.git"
        execute([git, "init", "--bare", str(remote)], base)
        seed = root / "seed"
        execute([git, "init", "--initial-branch=nocon", str(seed)], base)
        (seed / "desktop-only").write_text("fixture desktop state\n")
        execute([git, "-C", str(seed), "add", "."], base)
        execute([git, "-C", str(seed), "commit", "-m", "fixture"], base)
        execute([git, "-C", str(seed), "push", str(remote), "nocon"], base)

        def environment(name, **extra):
            home = root / name
            home.mkdir()
            runtime = home / "runtime"
            runtime.mkdir()
            events = home / "events"
            events.touch()
            return base | {
                "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_RUNTIME_DIR": str(runtime), "EVENTS": str(events),
                "STATE_PATH": str(home / "Desktop/infra/state"), "STATE_REMOTE": str(remote),
            } | extra

        deploy = [bash, os.environ["deployScript"], "--repo", str(repo)]
        for name, extra in [
            ("borrowed", {"ALLOW_PERSONAL": "false"}),
            ("wrong-host", {"CONFIGURED_HOST": "another-host"}),
        ]:
            env = environment(name, **extra)
            execute(deploy, env, success=False)
            assert pathlib.Path(env["EVENTS"]).read_text() == ""
            assert not (pathlib.Path(env["HOME"]) / ".config/sops/age/keys.txt").exists()

        checked = environment("check-only")
        execute(deploy + ["--check"], checked)
        assert pathlib.Path(checked["EVENTS"]).read_text() == ""
        assert not pathlib.Path(checked["STATE_PATH"]).exists()

        first = environment("first")
        execute(deploy, first)
        state = pathlib.Path(first["STATE_PATH"])
        events = pathlib.Path(first["EVENTS"]).read_text().splitlines()
        assert events.index("install-secrets") < events.index("network") < events.index("activate")
        assert not (state / "desktop-only").exists()
        execute([git, "-C", str(state), "rev-parse", "--verify", "HEAD"], first, success=False)
        history = state / ".local/state/bash/history"
        history.write_text("gcc fixture.c\n")
        commit = [bash, os.environ["commitScript"], "--repo-path", str(state), "--branch", branch]
        execute(commit + ["--check"], first)
        execute([git, "-C", str(state), "rev-parse", "--verify", "HEAD"], first, success=False)
        execute(commit, first)
        head = execute([git, "-C", str(state), "rev-parse", "HEAD"], first)
        execute(commit, first)
        assert execute([git, "-C", str(state), "rev-parse", "HEAD"], first) == head
        execute([bash, os.environ["commitScript"], "--repo-path", str(state), "--branch", "nocon"], first, success=False)
        execute([bash, os.environ["pushScript"], "--repo-path", str(state), "--branch", "nocon"], first, success=False)
        execute([bash, os.environ["pushScript"], "--repo-path", str(state), "--branch", branch], first)
        assert execute([git, "--git-dir", str(remote), "rev-parse", "refs/heads/" + branch], first) == head
        execute(deploy, first)
        assert execute([git, "-C", str(state), "rev-parse", "HEAD"], first) == head
        assert history.read_text() == "gcc fixture.c\n"

        restored = environment("restored")
        execute(deploy, restored)
        assert (pathlib.Path(restored["STATE_PATH"]) / ".local/state/bash/history").read_text() == "gcc fixture.c\n"

        wrong = environment("wrong-checkout")
        wrong_state = pathlib.Path(wrong["STATE_PATH"])
        wrong_state.parent.mkdir(parents=True)
        execute([git, "clone", "--branch", "nocon", str(remote), str(wrong_state)], wrong)
        execute(deploy, wrong, success=False)
        assert (wrong_state / "desktop-only").read_text() == "fixture desktop state\n"
        assert pathlib.Path(wrong["EVENTS"]).read_text() == ""

        offline = environment("offline", STATE_REMOTE=str(root / "unavailable.git"))
        execute(deploy, offline, success=False)
        assert not pathlib.Path(offline["STATE_PATH"]).exists()
        assert not list(pathlib.Path(offline["STATE_PATH"]).parent.glob("state.checkout.*"))
        assert "activate" not in pathlib.Path(offline["EVENTS"]).read_text()

        shell = environment("shell", ALLOW_PERSONAL="false")
        history_setup = 'HISTFILE="' + os.environ["historyFile"] + '"\nmkdir -p "$(dirname "$HISTFILE")"\nset -o history\n'
        execute([bash, "--noprofile", "--norc", "-c", history_setup + "history -s 'gcc fixture.c'; history -a"], shell)
        recalled = execute([bash, "--noprofile", "--norc", "-c", history_setup + "history -r; history"], shell)
        assert "gcc fixture.c" in recalled
        assert (pathlib.Path(shell["XDG_RUNTIME_DIR"]) / "bash/history").is_file()
        assert not pathlib.Path(shell["STATE_PATH"]).exists()
    PY
    touch "$out"
  ''
