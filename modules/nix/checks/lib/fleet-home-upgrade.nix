{
  pkgs,
  self,
  inputs,
}:
let
  username = "alice";
  home = "/home/${username}";
  source = "${home}/fleet-flake";
  planned = "0000000000000000000000000000000000000001";
  running = "0000000000000000000000000000000000000002";

  mkGeneration =
    revision:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        facts.id = "machine";
        inputs.self.lib.intent.deployPlan = {
          controller = null;
          hosts = { };
        };
      };
      modules = [
        (self + /modules/home/common/modules/fleet-home-upgrade.nix)
        {
          home = {
            inherit username;
            homeDirectory = home;
            stateVersion = "26.11";
            file.".fleet-generation".text = revision;
          };
          fleetHomeUpgrade = {
            inherit revision;
            planUrl = "http://127.0.0.1:8000/plan.json";
            flake = "path:${source}";
            configuration = "${username}@machine";
          };
        }
      ];
    }).activationPackage;

  base = mkGeneration planned;
  target = mkGeneration running;
  local = mkGeneration "${running}-dirty";
in
pkgs.testers.runNixOSTest {
  name = "fleet-home-upgrade";

  nodes.machine =
    { lib, ... }:
    {
      users.users.${username} = {
        isNormalUser = true;
        uid = 1000;
        linger = true;
      };
      system = {
        configurationRevision = running;
        extraDependencies = [
          base
          target
          local
        ];
      };
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        flake-registry = "";
        sandbox = false;
        substituters = lib.mkForce [ ];
      };
      systemd.services.plan-server = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8000 --bind 127.0.0.1 --directory /srv";
      };
      systemd.tmpfiles.rules = [ "d /srv 0755 root root -" ];
      virtualisation.memorySize = 2048;
    };

  testScript = ''
    import json

    def as_user(command):
        return machine.succeed(f"su - ${username} -c 'XDG_RUNTIME_DIR=/run/user/1000 {command}'")

    def generation():
        return as_user("cat ~/.fleet-generation").strip()

    def upgrade(expected):
        as_user("systemctl --user start fleet-home-upgrade.service")
        log = as_user("journalctl --user -u fleet-home-upgrade.service -o cat")
        run = log.rsplit("Starting ", 1)[-1]
        assert f"fleet-home-upgrade: {expected}" in run, log

    machine.wait_for_unit("user@1000.service")
    machine.wait_for_unit("plan-server.service")
    machine.wait_for_open_port(8000)

    flake = """
    {
      outputs = { self }: {
        homeConfigurations."${username}@machine".activationPackage = derivation {
          name = "home-manager-generation";
          system = "${pkgs.stdenv.hostPlatform.system}";
          builder = "/bin/sh";
          args = [ "-c" "${pkgs.coreutils}/bin/ln -s ${target} $out; true" ];
        };
      };
    }
    """
    machine.succeed(
        "install -d -o ${username} -g users ${source}",
        f"cat > ${source}/flake.nix <<'EOF'\n{flake}\nEOF",
    )
    machine.succeed(
        "cat > /srv/plan.json <<'EOF'\n"
        + json.dumps({"history": ["${running}", "${planned}"], "hosts": {}})
        + "\nEOF"
    )

    with subtest("a deployed generation follows the system revision"):
        as_user("${base}/activate")
        assert generation() == "${planned}"
        upgrade("current (none)")
        assert generation() == "${running}"
        assert as_user("cat ~/.local/state/nix/profiles/home-manager/fleet-revision").strip() == "${running}"
        upgrade("current (none)")

    with subtest("a dirty generation is left alone"):
        as_user("${local}/activate")
        upgrade("held (local)")
        assert generation() == "${running}-dirty"
  '';
}
