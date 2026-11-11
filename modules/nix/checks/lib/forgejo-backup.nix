{ pkgs }:
pkgs.runCommand "forgejo-backup"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.coreutils
      pkgs.curl
      pkgs.git
      pkgs.gnused
      pkgs.jq
      pkgs.util-linux
    ];
    backupScript = ../../../home/common/pkgs/bin/forgejo-backup.sh;
  }
  ''
    python3 - <<'PY'
    import fcntl
    import functools
    import http.server
    import json
    import os
    import pathlib
    import subprocess
    import tempfile
    import threading
    import urllib.parse

    git = "${pkgs.git}/bin/git"
    bash = "${pkgs.runtimeShell}"
    owner = "hakan-demirli"

    def execute(args, env, success=True):
        result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=120)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    def executable(path, body):
        path.write_text("#!${pkgs.python3}/bin/python3\n" + body)
        path.chmod(0o755)

    class Forge(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, status, payload):
            data = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if not url.path.startswith("/api/v1/"):
                return super().do_GET()
            if url.path == "/api/v1/version":
                return self.reply(200, {"version": "fixture"})
            if self.headers.get("Authorization") != "token forge-token":
                return self.reply(401, {"message": "bad credentials"})
            assert url.path == "/api/v1/repos/search", url.path
            page = int(urllib.parse.parse_qs(url.query)["page"][0])
            return self.reply(200, {"ok": True, "data": self.server.listed[(page - 1) * 2:page * 2]})

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        base = os.environ | {
            "HOME": str(root), "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        }
        served = root / "served"
        server = http.server.HTTPServer(("127.0.0.1", 0), functools.partial(Forge, directory=str(served)))
        server.listed = []
        threading.Thread(target=server.serve_forever, daemon=True).start()
        forge = "http://127.0.0.1:" + str(server.server_port)

        def upstream(name, repository_owner=owner):
            path = served / repository_owner / name
            execute([git, "init", "--quiet", "--bare", "--initial-branch=main", str(path)], base)
            execute([git, "--git-dir", str(path), "update-server-info"], base)
            return path

        def listing(*names, foreign=()):
            return [{"name": name, "owner": {"login": owner}} for name in names] + [
                {"name": name, "owner": {"login": "someone-else"}} for name in foreign
            ]

        work = root / "work"
        alpha = upstream("alpha")
        execute([git, "clone", "--quiet", str(alpha), str(work)], base)

        def commit(message):
            execute([git, "-C", str(work), "commit", "--quiet", "--allow-empty", "-m", message], base)
            return execute([git, "-C", str(work), "rev-parse", "HEAD"], base).stdout.strip()

        def push(target, *refspecs):
            execute([git, "-C", str(work), "push", "--quiet", "--force", str(target), *refspecs], base)
            execute([git, "--git-dir", str(target), "update-server-info"], base)

        def refs(git_dir):
            return execute([git, "--git-dir", str(git_dir), "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads", "refs/tags"], base).stdout

        commit("one")
        execute([git, "-C", str(work), "tag", "-a", "v1", "-m", "v1"], base)
        two = commit("two")
        side = commit("side")
        push(alpha, "HEAD:refs/heads/feature")
        execute([git, "-C", str(work), "reset", "--quiet", "--hard", two], base)
        push(alpha, "HEAD:refs/heads/main", "HEAD:refs/heads/stale", "refs/tags/v1")
        old = upstream("old")
        push(old, "HEAD:refs/heads/main")
        upstream("blank")
        upstream("theirs", repository_owner="someone-else")

        helper = root / "credential"
        executable(helper, f"""
    import sys
    if sys.argv[1] == "get":
        sys.stdin.read()
        print("username={owner}")
        print("password=forge-token")
    """)
        gitconfig = root / "gitconfig"
        gitconfig.write_text("[credential]\n\thelper = " + str(helper) + "\n[fetch]\n\tprune = true\n\tpruneTags = true\n")
        env = base | {"GIT_CONFIG_GLOBAL": str(gitconfig)}
        backup = root / "backup"

        def run(success):
            return execute([bash, os.environ["backupScript"], forge, owner, str(backup)], env, success)

        server.listed = listing("alpha", "old", "blank", "broken", foreign=["theirs"])
        failed = run(success=False).stderr
        assert "backing up broken failed" in failed, failed
        assert refs(backup / "alpha.git") == refs(alpha), refs(backup / "alpha.git")
        assert refs(backup / "old.git") == refs(old)
        assert (backup / "blank.git/HEAD").is_file()
        assert not (backup / "broken.git").exists()
        assert not (backup / "theirs.git").exists()
        assert list((backup / ".staging").iterdir()) == []
        for key, value in [("core.logAllRefUpdates", "always"), ("gc.reflogExpire", "never"), ("gc.reflogExpireUnreachable", "never")]:
            assert execute([git, "--git-dir", str(backup / "alpha.git"), "config", key], base).stdout.strip() == value, key

        three = commit("three")
        push(alpha, "HEAD:refs/heads/main", "HEAD:refs/heads/feature", ":refs/heads/stale")
        server.listed = listing("alpha", "blank", foreign=["theirs"])
        execute([git, "--git-dir", str(backup / "alpha.git"), "remote", "set-url", "origin", "http://127.0.0.1:1/elsewhere"], base)

        with open(backup / ".lock", "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            busy = run(success=False).stderr
            assert "another backup" in busy, busy

        run(success=True)
        mirror = backup / "alpha.git"
        assert execute([git, "--git-dir", str(mirror), "remote", "get-url", "origin"], base).stdout.strip() == forge + "/" + owner + "/alpha"
        assert execute([git, "--git-dir", str(mirror), "rev-parse", "main", "feature", "stale"], base).stdout.split() == [three, three, two]
        assert (mirror / "logs/refs/heads/feature").read_text().split()[:2] == [side, three]
        assert execute([git, "--git-dir", str(mirror), "cat-file", "-t", side], base).stdout.strip() == "commit"
        assert refs(backup / "old.git") == refs(old)
    PY
    touch "$out"
  ''
