{ pkgs, self }:
pkgs.runCommand "home-state-automation"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.git
      pkgs.util-linux
      pkgs.bash
      pkgs.coreutils
    ];
    backupScript = ../../../home/common/pkgs/bin/state-backup.sh;
    notesScript = ../../../home/common/pkgs/bin/notes-backup.sh;
    deployScript = ../../pkgs/bin/deploy-home-secrets.sh;
    historyFile = self.homeConfigurations."emre@shared-server-1".config.programs.bash.historyFile;
  }
  ''
    python3 - <<'PY'
    import http.server
    import os
    import pathlib
    import pwd
    import subprocess
    import tempfile
    import threading

    git = "${pkgs.git}/bin/git"
    bash = "${pkgs.runtimeShell}"
    branch = "hosts/fixture-host"

    def execute(args, env, success=True):
        result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=30)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result.stdout.strip()

    def executable(path, body):
        path.write_text("#!${pkgs.python3}/bin/python3\n" + body)
        path.chmod(0o755)

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        base = os.environ | {
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        }
        remote = root / "remote.git"
        execute([git, "init", "--bare", "--initial-branch=nocon", str(remote)], base)
        seed = root / "seed"
        execute([git, "init", "--initial-branch=nocon", str(seed)], base)
        seed_history = seed / ".local/state/bash/history"
        seed_history.parent.mkdir(parents=True)
        seed_history.write_text("remote history\n")
        execute([git, "-C", str(seed), "add", "."], base)
        execute([git, "-C", str(seed), "commit", "-m", "fixture"], base)
        execute([git, "-C", str(seed), "push", str(remote), "nocon"], base)

        def environment(name):
            home = root / name
            home.mkdir()
            runtime = home / "runtime"
            runtime.mkdir()
            return base | {"HOME": str(home), "XDG_RUNTIME_DIR": str(runtime)}

        def paths(env):
            home = pathlib.Path(env["HOME"])
            return home / ".local/share/state", home / ".local/state/bash/history"

        def backup(env, origin=remote, success=True):
            state, history = paths(env)
            return execute([bash, os.environ["backupScript"], str(state), branch, str(origin), str(history)], env, success)

        first = environment("first")
        state, history = paths(first)
        history.parent.mkdir(parents=True)
        history.write_text("discard this local file\n")
        backup(first)
        assert history.is_symlink()
        assert history.resolve() == state / ".local/state/bash/history"
        assert history.read_text() == "remote history\n"
        assert execute([git, "-C", str(state), "branch", "--show-current"], first) == branch
        assert execute([git, "--git-dir", str(remote), "show", branch + ":.local/state/bash/history"], first) == "remote history"

        history.write_text("remote history\nnew command\n")
        (state / "unrelated").write_text("leave staged\n")
        execute([git, "-C", str(state), "add", "unrelated"], first)
        backup(first)
        assert execute([git, "-C", str(state), "diff", "--cached", "--name-only"], first) == "unrelated"
        assert execute([git, "-C", str(state), "show", "--format=", "--name-only", "HEAD"], first) == ".local/state/bash/history"
        head = execute([git, "-C", str(state), "rev-parse", "HEAD"], first)
        assert execute([git, "--git-dir", str(remote), "rev-parse", branch], first) == head
        backup(first)
        assert execute([git, "-C", str(state), "rev-parse", "HEAD"], first) == head
        assert not list(pathlib.Path(first["HOME"]).rglob("*hm-backup*"))

        hook = remote / "hooks/pre-receive"
        executable(hook, "raise SystemExit(1)\n")
        history.write_text("remote history\nnew command\nretry this push\n")
        backup(first, success=False)
        unpushed = execute([git, "-C", str(state), "rev-parse", "HEAD"], first)
        assert unpushed != head
        assert execute([git, "--git-dir", str(remote), "rev-parse", branch], first) == head
        hook.unlink()
        backup(first)
        assert execute([git, "--git-dir", str(remote), "rev-parse", branch], first) == unpushed
        assert execute([git, "-C", str(state), "rev-parse", "HEAD"], first) == unpushed

        restored = environment("restored")
        restored_state, restored_history = paths(restored)
        backup(restored)
        assert restored_history.is_symlink()
        assert restored_history.read_text() == history.read_text()

        wrong = environment("wrong-branch")
        wrong_state, wrong_history = paths(wrong)
        wrong_state.parent.mkdir(parents=True)
        execute([git, "clone", "--branch", "nocon", str(remote), str(wrong_state)], wrong)
        backup(wrong)
        assert execute([git, "-C", str(wrong_state), "branch", "--show-current"], wrong) == branch
        assert wrong_history.read_text() == history.read_text()

        dirty = environment("dirty-branch")
        dirty_state, dirty_history = paths(dirty)
        dirty_state.parent.mkdir(parents=True)
        execute([git, "clone", "--branch", "nocon", str(remote), str(dirty_state)], dirty)
        (dirty_state / ".local/state/bash/history").write_text("uncommitted checkout history\n")
        dirty_history.parent.mkdir(parents=True)
        dirty_history.symlink_to(dirty_state / ".local/state/bash/history")
        backup(dirty, success=False)
        assert not dirty_history.is_symlink()
        assert dirty_history.read_text() == "uncommitted checkout history\n"
        assert execute([git, "-C", str(dirty_state), "branch", "--show-current"], dirty) == "nocon"
        assert (dirty_state / ".local/state/bash/history").read_text() == "uncommitted checkout history\n"

        offline = environment("offline")
        offline_state, offline_history = paths(offline)
        offline_history.parent.mkdir(parents=True)
        offline_history.write_text("keep local\n")
        backup(offline, root / "missing.git", success=False)
        assert not offline_state.exists()
        assert not offline_history.is_symlink()
        assert offline_history.read_text() == "keep local\n"
        assert not list(offline_state.parent.glob("state.checkout.*"))
        backup(offline)
        assert offline_history.is_symlink()
        assert offline_history.read_text() == history.read_text()

        class Denied(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(403)
                self.end_headers()
            def log_message(self, *args):
                pass
        server = http.server.HTTPServer(("127.0.0.1", 0), Denied)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        denied = environment("denied")
        try:
            backup(denied, "http://127.0.0.1:" + str(server.server_port) + "/state.git", success=False)
        finally:
            server.shutdown()
            server.server_close()
        denied_state, denied_history = paths(denied)
        assert denied_history.is_file() and not denied_history.is_symlink()
        assert not denied_state.exists()

        empty = root / "empty.git"
        execute([git, "init", "--bare", str(empty)], base)
        new = environment("empty-remote")
        backup(new, empty)
        assert execute([git, "--git-dir", str(empty), "show", branch + ":.local/state/bash/history"], new) == ""

        storage = environment("storage")
        storage_state, storage_history = paths(storage)
        persistent = root / "persistent-state"
        persistent.mkdir()
        storage_state.parent.mkdir(parents=True)
        storage_state.symlink_to(persistent, target_is_directory=True)
        backup(storage)
        assert storage_state.is_symlink()
        assert storage_history.resolve() == persistent / ".local/state/bash/history"

        notes_remote = root / "notes.git"
        execute([git, "init", "--bare", "--initial-branch=notes", str(notes_remote)], base)
        notes_seed = root / "notes-seed"
        execute([git, "init", "--initial-branch=notes", str(notes_seed)], base)
        (notes_seed / "scratchpads").mkdir()
        (notes_seed / "scratchpads/todo.md").write_text("seed\n")
        (notes_seed / "keep.txt").write_text("seed\n")
        execute([git, "-C", str(notes_seed), "add", "."], base)
        execute([git, "-C", str(notes_seed), "commit", "-m", "notes fixture"], base)
        execute([git, "-C", str(notes_seed), "push", str(notes_remote), "notes"], base)

        notes = environment("notes")
        notes_repo = pathlib.Path(notes["HOME"]) / "Desktop/infra/state"
        note = notes_repo / "scratchpads/todo.md"

        def publish(origin=notes_remote, success=True):
            return execute([bash, os.environ["notesScript"], str(notes_repo), "notes", str(origin), "scratchpads"], notes, success)

        def remote_head(origin=notes_remote):
            return execute([git, "--git-dir", str(origin), "rev-parse", "notes"], notes)

        publish()
        assert not notes_repo.exists()

        notes_repo.parent.mkdir(parents=True)
        execute([git, "clone", "--branch", "notes", str(notes_remote), str(notes_repo)], notes)
        seeded = remote_head()
        publish()
        assert execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes) == seeded

        note.write_text("seed\nnew note\n")
        (notes_repo / "keep.txt").write_text("untracked by the service\n")
        publish()
        head = execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes)
        assert head != seeded
        assert remote_head() == head
        assert execute([git, "-C", str(notes_repo), "show", "--format=", "--name-only", "HEAD"], notes) == "scratchpads/todo.md"
        assert execute([git, "-C", str(notes_repo), "status", "--porcelain"], notes) == "M keep.txt"

        execute([git, "-C", str(notes_repo), "add", "keep.txt"], notes)
        note.write_text("seed\nnew note\nanother\n")
        publish()
        assert execute([git, "-C", str(notes_repo), "diff", "--cached", "--name-only"], notes) == "keep.txt"
        head = execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes)

        publish(root / "missing.git", success=False)
        assert execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes) == head

        execute([git, "-C", str(notes_repo), "switch", "--quiet", "-c", "elsewhere"], notes)
        note.write_text("seed\nnew note\nanother\nwrong branch\n")
        publish(success=False)
        assert execute([git, "-C", str(notes_repo), "branch", "--show-current"], notes) == "elsewhere"
        assert execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes) == head
        assert note.read_text() == "seed\nnew note\nanother\nwrong branch\n"
        execute([git, "-C", str(notes_repo), "switch", "--quiet", "notes"], notes)

        notes_hook = notes_remote / "hooks/pre-receive"
        executable(notes_hook, "raise SystemExit(1)\n")
        publish(success=False)
        unpublished = execute([git, "-C", str(notes_repo), "rev-parse", "HEAD"], notes)
        assert unpublished != head
        assert remote_head() == head
        notes_hook.unlink()
        publish()
        assert remote_head() == unpublished

        tools = root / "tools"
        tools.mkdir()
        executable(tools / "hostname", 'print("fixture-host")\n')
        executable(tools / "nix", r"""
    import os, sys
    target = sys.argv[-1]
    values = {"homeSops.enable": os.environ.get("ALLOW_PERSONAL", "true"),
              "DOTFILES_HOST": os.environ.get("CONFIGURED_HOST", "fixture-host"),
              "home.username": os.environ["FIXTURE_USER"], "homeSops.identity": "user-0",
              "homeSops.ageKeyFile": os.environ["HOME"] + "/key", "homeSops.bootstrap": os.environ["BOOTSTRAP"]}
    print(next(value for key, value in values.items() if target.endswith(key)))
    """)
        executable(tools / "age", r"""
    import pathlib, sys
    pathlib.Path(sys.argv[sys.argv.index("--output") + 1]).write_text("fixture")
    """)
        executable(tools / "age-keygen", 'print("fixture-recipient")\n')
        bootstrap = root / "bootstrap/bin"
        bootstrap.mkdir(parents=True)
        executable(bootstrap / "bootstrap-home-secrets", r"""
    import os, pathlib
    home = pathlib.Path(os.environ["HOME"])
    for name in [".config/git/git_users", ".config/sops-nix/secrets/git_tokens", ".ssh/id_ed25519", ".ssh/id_ed25519_proton", ".ssh/id_ed25519_sf"]:
        path = home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture")
    """)
        executable(tools / "home-manager", r"""
    import os, pathlib
    home = pathlib.Path(os.environ["HOME"])
    assert (home / ".config/sops-nix/secrets/git_tokens").is_file()
    (home / "activated").touch()
    """)
        repo = root / "dotfiles"
        envelopes = repo / "secrets/identities"
        envelopes.mkdir(parents=True)
        (repo / "flake.nix").touch()
        (envelopes / "home-user-0.age.key.enc").write_text("-----BEGIN AGE ENCRYPTED FILE-----\n")
        (envelopes / "home-user-0.age.pub").write_text("fixture-recipient\n")
        deploy_env = environment("deploy") | {"PATH": str(tools) + ":" + base["PATH"],
            "BOOTSTRAP": str(bootstrap.parent), "FIXTURE_USER": pwd.getpwuid(os.getuid()).pw_name}
        deploy = [bash, os.environ["deployScript"], "--repo", str(repo)]
        execute(deploy, deploy_env | {"ALLOW_PERSONAL": "false"}, success=False)
        execute(deploy, deploy_env | {"CONFIGURED_HOST": "another-host"}, success=False)
        execute(deploy + ["--check"], deploy_env)
        assert not (pathlib.Path(deploy_env["HOME"]) / "key").exists()
        execute(deploy, deploy_env)
        assert (pathlib.Path(deploy_env["HOME"]) / "activated").exists()
        assert not paths(deploy_env)[0].exists()

        shell = environment("borrowed-shell")
        setup = 'HISTFILE="' + os.environ["historyFile"] + '"\nmkdir -p "$(dirname "$HISTFILE")"\nset -o history\n'
        execute([bash, "--noprofile", "--norc", "-c", setup + "history -s 'gcc fixture.c'; history -a"], shell)
        assert "gcc fixture.c" in execute([bash, "--noprofile", "--norc", "-c", setup + "history -r; history"], shell)
    PY
    touch "$out"
  ''
