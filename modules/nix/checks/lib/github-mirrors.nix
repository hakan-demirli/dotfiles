{ pkgs }:
pkgs.runCommand "github-mirrors"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.git
      pkgs.gnused
      pkgs.jq
    ];
    mirrorScript = ../../../home/common/pkgs/bin/github-mirrors.sh;
  }
  ''
    python3 - <<'PY'
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
        result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=60)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    def executable(path, body):
        path.write_text("#!${pkgs.python3}/bin/python3\n" + body)
        path.chmod(0o755)

    class Api(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, status, payload):
            data = b"" if payload is None else json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def answer(self, method):
            url = urllib.parse.urlparse(self.path)
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length)) if length else None
            if self.headers.get("Authorization") != "token " + self.server.token:
                return self.reply(401, {"message": "bad credentials"})
            self.server.calls.append((method, url.path))
            self.reply(*self.server.api.route(method, url.path, urllib.parse.parse_qs(url.query), body))

        def do_GET(self):
            self.answer("GET")

        def do_POST(self):
            self.answer("POST")

        def do_DELETE(self):
            self.answer("DELETE")

    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass

    def serve(handler, **attributes):
        server = http.server.HTTPServer(("127.0.0.1", 0), handler)
        for key, value in attributes.items():
            setattr(server, key, value)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return server

    class Forgejo:
        def __init__(self):
            self.repositories = []
            self.mirrors = {}
            self.commits = {}
            self.synced = []

        def add(self, name, repository_owner=owner, **flags):
            self.repositories.append({"name": name, "owner": {"login": repository_owner}, "archived": False, "mirror": False, "fork": False, "empty": False} | flags)

        def route(self, method, path, query, body):
            parts = path.removeprefix("/api/v1/").split("/")
            if method == "GET" and parts == ["repos", "search"]:
                page = int(query["page"][0])
                return 200, {"ok": True, "data": self.repositories[(page - 1) * 2:page * 2]}
            _, repository_owner, name, *rest = parts
            assert repository_owner == owner, path
            mirrors = self.mirrors.setdefault(name, [])
            if method == "GET" and rest == ["push_mirrors"]:
                return 200, mirrors
            if method == "POST" and rest == ["push_mirrors"]:
                mirror = body | {"remote_name": "remote_mirror_" + name, "last_error": ""}
                mirrors.append(mirror)
                return 200, mirror | {"public_key": "ssh-ed25519 KEY" + name}
            if method == "DELETE" and rest[:1] == ["push_mirrors"]:
                self.mirrors[name] = [mirror for mirror in mirrors if mirror["remote_name"] != rest[1]]
                return 204, None
            if method == "POST" and rest == ["push_mirrors-sync"]:
                self.synced.append(name)
                return 200, None
            if method == "GET" and rest[:2] == ["git", "commits"]:
                if rest[2] in self.commits.get(name, set()):
                    return 200, {"sha": rest[2]}
                return 404, {"message": "commit not found"}
            return 500, {"message": "unexpected " + method + " " + path}

    class GitHub:
        def __init__(self, root, env):
            self.root = root
            self.env = env
            self.repositories = {}
            self.created = []
            self.keys = {}
            self.refused = set()

        def init(self, name, fork=False):
            path = self.root / owner / name
            execute([git, "init", "--quiet", "--bare", "--initial-branch=main", str(path)], self.env)
            execute([git, "--git-dir", str(path), "update-server-info"], self.env)
            self.repositories[name] = {"name": name, "fork": fork}
            return path

        def route(self, method, path, query, body):
            parts = path.strip("/").split("/")
            if method == "POST" and parts == ["user", "repos"]:
                self.created.append(body)
                self.init(body["name"])
                return 201, self.repositories[body["name"]]
            _, repository_owner, name, *rest = parts
            assert repository_owner == owner, path
            if method == "GET" and not rest:
                if name in self.repositories:
                    return 200, self.repositories[name]
                return 404, {"message": "Not Found"}
            if method == "POST" and rest == ["keys"]:
                if name in self.refused:
                    return 422, {"message": "key is already in use"}
                self.keys.setdefault(name, []).append(body)
                return 201, body
            return 500, {"message": "unexpected " + method + " " + path}

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        base = os.environ | {
            "HOME": str(root), "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        }
        hosted = root / "github"
        forge = Forgejo()
        hub = GitHub(hosted, base)
        forge_server = serve(Api, api=forge, token="forge-token", calls=[])
        hub_server = serve(Api, api=hub, token="github-token", calls=[])
        web = serve(functools.partial(Quiet, directory=str(hosted)))
        forge_host = "127.0.0.1:" + str(forge_server.server_port)

        def publish(path, message, tag=None):
            work = root / ("work-" + path.name)
            if not work.exists():
                execute([git, "clone", "--quiet", str(path), str(work)], base)
            execute([git, "-C", str(work), "commit", "--quiet", "--allow-empty", "-m", message], base)
            if tag:
                execute([git, "-C", str(work), "tag", "-a", tag, "-m", tag], base)
            execute([git, "-C", str(work), "push", "--quiet", "--follow-tags", "origin", "HEAD:refs/heads/main"], base)
            execute([git, "--git-dir", str(path), "update-server-info"], base)
            return execute([git, "-C", str(work), "rev-parse", "HEAD"], base).stdout.strip()

        forge.add("fresh")
        forge.add("mirrored")
        forge.mirrors["mirrored"] = [{"remote_name": "remote_mirror_mirrored", "last_error": ""}]
        forge.add("broken")
        forge.mirrors["broken"] = [{"remote_name": "remote_mirror_broken", "last_error": "fatal: denied\nmore detail"}]
        forge.add("state")
        forge.mirrors["state"] = [{"remote_name": "remote_mirror_state", "last_error": ""}]
        tagged = publish(hub.init("contained"), "contained", tag="v1")
        forge.add("contained")
        forge.commits["contained"] = {tagged}
        ahead = publish(hub.init("collide"), "only on github")
        forge.add("collide")
        hub.init("forked", fork=True)
        forge.add("forked")
        forge.add("keyfail")
        hub.refused.add("keyfail")
        forge.add("old", archived=True)
        forge.add("pulled", mirror=True)
        forge.add("copy", fork=True)
        forge.add("blank", empty=True)
        forge.add("foreign", repository_owner="someone-else")

        helper = root / "credential"
        executable(helper, f"""
    import sys
    if sys.argv[1] == "get":
        fields = dict(line.split("=", 1) for line in sys.stdin.read().splitlines() if "=" in line)
        print("username={owner}")
        print("password=" + ("forge-token" if fields.get("host") == "{forge_host}" else "github-token"))
    """)
        gitconfig = root / "gitconfig"
        gitconfig.write_text("[credential]\n\thelper = " + str(helper) + "\n")
        config = root / "config.json"
        config.write_text(json.dumps({
            "owner": owner,
            "forge": "http://" + forge_host,
            "github": {
                "api": "http://127.0.0.1:" + str(hub_server.server_port),
                "web": "http://127.0.0.1:" + str(web.server_port),
                "ssh": "ssh://git@github.example",
            },
            "interval": "8h0m0s",
            "excluded": ["state"],
        }))
        env = base | {"GIT_CONFIG_GLOBAL": str(gitconfig)}

        def run(success):
            return execute([bash, os.environ["mirrorScript"], str(config)], env, success)

        def touched(server, name):
            return [call for call in server.calls if "/" + name + "/" in call[1] + "/"]

        failed = run(success=False).stderr
        assert "pushing broken failed: fatal: denied" in failed, failed
        assert "more detail" not in failed, failed
        assert "has " + ahead + ", which Forgejo lacks; not mirroring collide" in failed, failed
        assert "is a fork; not mirroring forked" in failed, failed
        assert "refused the deploy key of keyfail" in failed, failed

        assert hub.created == [{"name": "fresh", "private": True}, {"name": "keyfail", "private": True}], hub.created
        for name in ["fresh", "contained"]:
            assert forge.mirrors[name] == [{
                "remote_address": "ssh://git@github.example/" + owner + "/" + name + ".git",
                "use_ssh": True, "interval": "8h0m0s", "sync_on_commit": True,
                "remote_name": "remote_mirror_" + name, "last_error": "",
            }], forge.mirrors[name]
            assert hub.keys[name] == [{"title": "forgejo-push-mirror", "key": "ssh-ed25519 KEY" + name, "read_only": False}]
        assert forge.synced == ["fresh", "contained"], forge.synced
        assert forge.mirrors["state"] == []
        for name in ["collide", "forked", "keyfail"]:
            assert forge.mirrors[name] == [], (name, forge.mirrors[name])
        assert "keyfail" not in hub.keys
        assert len(forge.mirrors["mirrored"]) == 1 and len(forge.mirrors["broken"]) == 1
        for name in ["mirrored", "broken", "state", "old", "pulled", "copy", "blank", "foreign"]:
            assert not touched(hub_server, name), (name, hub_server.calls)
        for name in ["old", "pulled", "copy", "blank", "foreign"]:
            assert not touched(forge_server, name), (name, forge_server.calls)

        forge.mirrors["broken"][0]["last_error"] = ""
        forge.commits["collide"] = {ahead}
        forge.repositories = [repository for repository in forge.repositories if repository["name"] != "forked"]
        hub.refused.clear()
        run(success=True)
        assert len(hub.created) == 2, hub.created
        for name in ["fresh", "contained", "collide", "keyfail", "mirrored", "broken"]:
            assert len(forge.mirrors[name]) == 1, (name, forge.mirrors[name])
        assert forge.synced == ["fresh", "contained", "collide", "keyfail"], forge.synced
    PY
    touch "$out"
  ''
