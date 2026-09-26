{
  pkgs,
  self,
  inputs,
}:
let
  username = "alice";
  home = "/home/${username}";
  persist = "/persist/home/${username}";

  homeConfiguration = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      (self + /modules/home/common/modules/home-storage.nix)
      {
        home = {
          inherit username;
          homeDirectory = home;
          stateVersion = "26.11";
          packages = [ pkgs.hello ];
        };
        homeStorage = {
          enable = true;
          default = "temporary";
          paths = {
            ".cache" = "temporary";
            ".config/example.conf" = {
              storage = "persistent";
              type = "file";
            };
            ".config/sops/age" = "persistent";
            ".local/share/state" = "persistent";
            Desktop = "persistent";
          };
        };
      }
    ];
  };
  generation = homeConfiguration.activationPackage;
  generationId = builtins.unsafeDiscardStringContext (builtins.baseNameOf generation);
in
pkgs.testers.runNixOSTest {
  name = "home-storage-activation";

  nodes.machine = {
    users.users.${username} = {
      isNormalUser = true;
      uid = 1000;
    };
    system.extraDependencies = [ generation ];
    virtualisation.memorySize = 1024;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    for bucket in ["persistent", "temporary", "control"]:
        machine.succeed(
            f"install -d -o ${username} -g users -m 0700 ${persist}/{bucket} ${home}/.storage/{bucket}",
            f"mount --bind ${persist}/{bucket} ${home}/.storage/{bucket}",
        )

    machine.fail("test -e ${home}/.config")
    machine.fail("su - ${username} -c 'sudo -n true'")

    for attempt in ["fresh home", "existing links"]:
        with subtest(f"activation as ${username} without sudo: {attempt}"):
            machine.succeed("su - ${username} -c ${generation}/activate")
            machine.succeed(
                "test \"$(readlink ${home}/.config/sops/age)\" = ${home}/.storage/persistent/.config/sops/age",
                "test -d ${home}/.storage/persistent/.config/sops/age",
                "test \"$(stat -c %U ${home}/.config/sops)\" = ${username}",
                "test \"$(readlink ${home}/.config/example.conf)\" = ${home}/.storage/persistent/.config/example.conf",
                "test -f ${home}/.storage/persistent/.config/example.conf",
                "test \"$(readlink ${home}/.local/share/state)\" = ${home}/.storage/persistent/.local/share/state",
                "test \"$(readlink ${home}/.cache)\" = ${home}/.storage/temporary/.cache",
                "test \"$(readlink ${home}/Desktop)\" = ${home}/.storage/persistent/Desktop",
                "test \"$(readlink ${persist}/control/current)\" = generations/${generationId}/home-storage-policy",
            )
            machine.succeed("su - ${username} -c 'command -v hello'")
  '';
}
