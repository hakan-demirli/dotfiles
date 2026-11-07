{
  pkgs,
  self,
  inputs,
}:
let
  inherit (pkgs) lib;

  adminUser = "forge-admin";
  adminPassword = "correct-horse-battery-staple";
  passwordFile = "/var/lib/forgejo-test/admin-password";

  pushKey =
    pkgs.runCommand "forgejo-repositories-test-key" { nativeBuildInputs = [ pkgs.openssh ]; }
      ''
        mkdir $out
        ssh-keygen -q -t ed25519 -N "" -C pusher@test -f $out/id_ed25519
      '';

  sopsOptionStubs = {
    options.sops.secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "forgejo-repositories";

  nodes.forge =
    { pkgs, ... }:
    {
      imports = [
        (import (inputs.infra-lib + "/modules/nix/checks/lib/lib/vm-impermanence.nix") { inherit inputs; })
        sopsOptionStubs
        (inputs.infra-lib + "/modules/services/forgejo.nix")
        (self + "/modules/services/forgejo-repositories.nix")
      ];

      _module.args.host = {
        id = "forge";
        impermanence.enable = true;
      };

      services = {
        openssh.enable = true;

        cluster-forgejo = {
          domain = "forge";
          admin = {
            username = adminUser;
            email = "${adminUser}@example.com";
            password = {
              source = "host-local";
              hostLocalPath = passwordFile;
            };
          };
        };

        forgejo.settings.service.REQUIRE_SIGNIN_VIEW = lib.mkForce false;

        forgejo-repositories = {
          users.bot.email = "bot@example.com";
          repositories = {
            demo = {
              defaultBranch = "unstable";
              topics = [ "ci" ];
              collaborators.bot = "admin";
              settings.allow_merge_commits = false;
              branchProtections.release = {
                enable_push = true;
                enable_push_whitelist = true;
                push_whitelist_usernames = [ "bot" ];
                apply_to_admins = true;
              };
            };
            secret.private = true;
          };
          sshKeys = [ (lib.fileContents "${pushKey}/id_ed25519.pub") ];
        };
      };

      systemd.services.forgejo-test-password = {
        description = "Seed the Forgejo administrator password for THIS TEST ONLY";
        wantedBy = [ "multi-user.target" ];
        before = [ "forgejo-admin.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          install -d -m 0700 ${builtins.dirOf passwordFile}
          printf '%s' ${lib.escapeShellArg adminPassword} > ${passwordFile}
          chmod 0400 ${passwordFile}
        '';
      };

      environment.systemPackages = [
        pkgs.curl
        pkgs.git
        pkgs.jq
        pkgs.openssh
      ];

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    import json

    api = "http://localhost:3001/api/v1"
    auth = "-u ${adminUser}:${adminPassword}"


    def api_get(path):
        return json.loads(forge.succeed("curl -sf " + auth + " '" + api + path + "'"))


    def repo_private(name):
        return api_get("/repos/${adminUser}/" + name)["private"]


    forge.start()
    forge.wait_for_unit("forgejo-repositories.service")

    with subtest("declared repositories exist with declared visibility"):
        assert repo_private("demo") is False
        assert repo_private("secret") is True

    with subtest("declared repository policy is applied"):
        demo = api_get("/repos/${adminUser}/demo")
        assert demo["allow_merge_commits"] is False, demo
        assert demo["default_branch"] == "unstable", demo
        assert api_get("/repos/${adminUser}/demo/topics")["topics"] == ["ci"]
        collaborators = api_get("/repos/${adminUser}/demo/collaborators")
        assert [c["login"] for c in collaborators] == ["bot"], collaborators
        permission = api_get("/repos/${adminUser}/demo/collaborators/bot/permission")
        assert permission["permission"] == "admin", permission
        protection = api_get("/repos/${adminUser}/demo/branch_protections/release")
        assert protection["push_whitelist_usernames"] == ["bot"], protection
        assert protection["apply_to_admins"] is True, protection

    with subtest("administrator pushes over the host sshd with a declared key"):
        forge.succeed("install -d -m 0700 /root/.ssh")
        forge.succeed("install -m 0600 ${pushKey}/id_ed25519 /root/.ssh/id_ed25519")
        forge.succeed(
            "git init -q -b main /tmp/seed"
            " && echo pushed > /tmp/seed/README"
            " && git -C /tmp/seed add README"
            " && git -C /tmp/seed -c user.name=t -c user.email=t@example.com commit -q -m seed"
        )
        forge.succeed(
            "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' "
            "git -C /tmp/seed push -q ssh://forgejo@localhost/${adminUser}/demo.git main"
        )

    with subtest("the default branch survives reprovisioning once it exists"):
        forge.succeed(
            "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' "
            "git -C /tmp/seed push -q ssh://forgejo@localhost/${adminUser}/demo.git main:unstable"
        )
        forge.wait_until_succeeds(
            "curl -sf " + auth + " " + api + "/repos/${adminUser}/demo/branches/unstable"
        )
        forge.succeed("systemctl restart forgejo-repositories.service")
        assert api_get("/repos/${adminUser}/demo")["default_branch"] == "unstable"

    with subtest("a protected branch refuses the administrator"):
        forge.succeed("git -C /tmp/seed -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m next")
        forge.fail(
            "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' "
            "git -C /tmp/seed push -q ssh://forgejo@localhost/${adminUser}/demo.git main:release"
        )

    with subtest("fleet hosts clone public repositories without credentials"):
        forge.succeed("git clone -q http://localhost:3001/${adminUser}/demo.git /tmp/anonymous")
        forge.succeed("grep -qx pushed /tmp/anonymous/README")
        forge.fail("GIT_TERMINAL_PROMPT=0 git clone -q http://localhost:3001/${adminUser}/secret.git /tmp/leak")

    with subtest("reprovisioning converges drift"):
        forge.succeed(
            "curl -sf " + auth + " -X PATCH -H 'Content-Type: application/json'"
            " -d '{\"private\": true}' " + api + "/repos/${adminUser}/demo"
        )
        forge.succeed("ssh-keygen -q -t ed25519 -N \"\" -C stray@test -f /tmp/stray")
        stray = forge.succeed("cat /tmp/stray.pub").strip()
        forge.succeed(
            "curl -sf " + auth + " -X POST -H 'Content-Type: application/json'"
            " -d '" + json.dumps({"title": "stray", "key": stray}) + "' " + api + "/user/keys"
        )
        forge.succeed(
            "curl -sf " + auth + " -X DELETE " + api + "/repos/${adminUser}/demo/collaborators/bot"
        )
        forge.succeed("systemctl restart forgejo-repositories.service")
        assert repo_private("demo") is False
        assert [c["login"] for c in api_get("/repos/${adminUser}/demo/collaborators")] == ["bot"]
        keys = api_get("/user/keys")
        assert [k["title"] for k in keys] == ["pusher@test"], keys
        listing = api_get("/repos/search?q=demo")
        assert len(listing["data"]) == 1, listing

    print("FORGEJO REPOSITORY VERIFICATIONS PASSED")
  '';
}
