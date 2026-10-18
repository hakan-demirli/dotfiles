{
  pkgs,
  self,
  inputs,
}:
let
  inherit (pkgs) lib;

  users = {
    alice = 1000;
    bob = 1001;
    carol = 1002;
  };

  mkGeneration =
    username:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        (self + /modules/home/common/modules/home-storage.nix)
        {
          home = {
            inherit username;
            homeDirectory = "/home/${username}";
            stateVersion = "26.11";
            packages = [ pkgs.hello ];
            file.probe.text = "probe\n";
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
    }).activationPackage;

  generations = lib.mapAttrs (username: _: mkGeneration username) users;
  generationId =
    username: builtins.unsafeDiscardStringContext (builtins.baseNameOf generations.${username});
in
pkgs.testers.runNixOSTest {
  name = "home-storage-activation";

  nodes.machine = {
    users.users = lib.mapAttrs (_: uid: {
      isNormalUser = true;
      inherit uid;
    }) users;
    system.extraDependencies = lib.attrValues generations;
    virtualisation.memorySize = 1024;
  };

  testScript = ''
    import shlex

    def as_user(user, command):
        return f"su - {user} -c {shlex.quote(command)}"

    def mount_storage(user):
        machine.succeed(f"install -d -o {user} -g users -m 0700 /home/{user}/.storage")
        for bucket in ["persistent", "temporary", "control"]:
            machine.succeed(
                f"install -d -o {user} -g users -m 0700 /persist/home/{user}/{bucket} /home/{user}/.storage/{bucket}",
                f"mount --bind /persist/home/{user}/{bucket} /home/{user}/.storage/{bucket}",
            )

    machine.wait_for_unit("multi-user.target")
    machine.fail(as_user("alice", "sudo -n true"))

    with subtest("dry run changes nothing"):
        mount_storage("alice")
        machine.succeed(as_user("alice", "DRY_RUN=1 ${generations.alice}/activate"))
        machine.succeed(
            "! test -e /home/alice/Desktop",
            "! test -e /home/alice/.storage/persistent/Desktop",
            "! test -e /home/alice/probe",
            "! test -e /persist/home/alice/control/current",
        )

    for attempt in ["fresh home", "existing links"]:
        with subtest(f"activation as alice without sudo: {attempt}"):
            machine.succeed(as_user("alice", "${generations.alice}/activate"))
            machine.succeed(
                "test \"$(readlink /home/alice/Desktop)\" = /home/alice/.storage/persistent/Desktop",
                "test -d /home/alice/.storage/persistent/Desktop",
                "test \"$(readlink /home/alice/.config/sops/age)\" = /home/alice/.storage/persistent/.config/sops/age",
                "test \"$(stat -c %U /home/alice/.config/sops)\" = alice",
                "test \"$(readlink /home/alice/.local/share/state)\" = /home/alice/.storage/persistent/.local/share/state",
                "test \"$(readlink /home/alice/.config/example.conf)\" = /home/alice/.storage/persistent/.config/example.conf",
                "test -f /home/alice/.storage/persistent/.config/example.conf",
                "test \"$(readlink /home/alice/.cache)\" = /home/alice/.storage/temporary/.cache",
                "test \"$(cat /home/alice/probe)\" = probe",
                "test \"$(readlink /persist/home/alice/control/current)\" = generations/${generationId "alice"}/home-storage-policy",
                "test \"$(readlink -e /home/alice/.local/state/home-manager/gcroots/current-home)\" = ${generations.alice}",
            )
            machine.succeed(as_user("alice", "command -v hello"))

    with subtest("unmanaged paths stop activation before any write"):
        mount_storage("bob")
        machine.succeed(
            as_user("bob", "mkdir -p ~/Desktop ~/.config/sops"),
            as_user("bob", "echo live > ~/Desktop/live"),
            as_user("bob", "ln -s /elsewhere ~/.config/sops/age"),
            as_user("bob", "ln -s /nix/store/00000000000000000000000000000000-stale ~/.storage/temporary/.cache"),
        )
        status, output = machine.execute(as_user("bob", "${generations.bob}/activate 2>&1"))
        assert status != 0, output
        assert "/home/bob/Desktop is not managed by home-storage" in output, output
        assert "/home/bob/.config/sops/age links to /elsewhere" in output, output
        assert "/home/bob/.storage/temporary/.cache must be a directory" in output, output
        machine.succeed(
            "test \"$(cat /home/bob/Desktop/live)\" = live && ! test -L /home/bob/Desktop",
            "! test -e /home/bob/.storage/persistent/Desktop",
            "! test -e /home/bob/probe",
            "! test -e /home/bob/.cache",
            "! test -e /home/bob/.local/state/nix/profiles/home-manager",
            "! test -e /persist/home/bob/control/current",
        )

    with subtest("activation succeeds once the paths are resolved by hand"):
        machine.succeed(
            as_user("bob", "mkdir -p ~/.storage/persistent && mv ~/Desktop ~/.storage/persistent/Desktop"),
            as_user("bob", "rm ~/.config/sops/age ~/.storage/temporary/.cache"),
        )
        machine.succeed(as_user("bob", "${generations.bob}/activate"))
        machine.succeed(
            "test \"$(readlink /home/bob/Desktop)\" = /home/bob/.storage/persistent/Desktop",
            "test \"$(cat /home/bob/Desktop/live)\" = live",
            "test \"$(readlink /home/bob/.cache)\" = /home/bob/.storage/temporary/.cache",
            "test \"$(readlink /persist/home/bob/control/current)\" = generations/${generationId "bob"}/home-storage-policy",
        )

    with subtest("standalone activation without the storage facility"):
        machine.succeed(as_user("carol", "${generations.carol}/activate"))
        machine.succeed(
            "test \"$(cat /home/carol/probe)\" = probe",
            "! test -e /home/carol/Desktop",
            "! test -L /home/carol/.cache",
            "! test -e /persist/home/carol",
            "test \"$(readlink -e /home/carol/.local/state/home-manager/gcroots/current-home)\" = ${generations.carol}",
        )
        machine.succeed(as_user("carol", "command -v hello"))
  '';
}
