{
  pkgs,
  self,
  lib,
}:
let
  homes = {
    desktop = self.homeConfigurations."user-0@desktop";
    desktop-nvidia = self.homeConfigurations."user-0@desktop-nvidia";
    headless = self.homeConfigurations."user-0@headless";
    vps-oracle-0 = self.homeConfigurations."user-0@vps-oracle-0";
  };
  profiles = [
    homes.desktop
    homes.desktop-nvidia
    homes.headless
    homes.vps-oracle-0
  ];
  expectedPaths = {
    ".cache" = "persistent";
    ".config/mozilla" = "persistent";
    ".config/sops/age" = "persistent";
    ".local/share/opencode" = "persistent";
    ".local/state/opencode" = "persistent";
    ".local/state/wireplumber" = "persistent";
    Desktop = "persistent";
    Documents = "persistent";
    Downloads = "persistent";
    Videos = "persistent";
  };
  actual = homes.desktop.config;
  activation = actual.home.activation.homeStoragePolicy.data;
  publication = actual.home.activation.publishHomeStorageGeneration;
  userServiceCommands =
    map (name: builtins.head actual.systemd.user.services.${name}.Service.ExecStart)
      [
        "github-backup"
        "ntfy-listener"
        "state-autocommit"
        "state-autopush"
      ];

  checks = {
    real-identity = actual.home.username == "emre" && actual.home.homeDirectory == "/home/emre";
    real-policy-enabled = actual.homeStorage.enable;
    real-policy-is-temporary-by-default = actual.homeStorage.default == "temporary";
    real-persistent-paths = actual.homeStorage.paths == expectedPaths;
    policy-is-profile-independent = lib.all (
      home:
      home.config.homeStorage.default == "temporary" && home.config.homeStorage.paths == expectedPaths
    ) profiles;
    facility-is-optional = lib.hasInfix "home-storage facility unavailable" activation;
    storage-namespace-is-user-owned =
      lib.hasInfix "/home/emre/.storage/persistent" activation
      && lib.hasInfix "/home/emre/.storage/temporary" activation
      && lib.hasInfix "/home/emre/.storage/control" activation;
    legacy-links-are-relinked =
      lib.hasInfix "/home/emre/.home-storage/" activation
      && lib.hasInfix "relinking legacy path" activation;
    publication-is-atomic = lib.hasInfix ''mv -Tf "$next" "$control/current"'' publication.data;
    current-is-the-only-commit-pointer = !lib.hasInfix "replay-required" publication.data;
    generation-is-persistently-installed =
      lib.hasInfix ''generations="$persistentControl/generations"'' publication.data
      && lib.hasInfix ''--add-root "$persistentGeneration"'' publication.data
      && lib.hasInfix ''generationId="''${newGenPath##*/}"'' publication.data
      && lib.hasInfix "/persist/home/emre/control" publication.data;
    publication-retains-current-and-candidate =
      lib.hasInfix ''oldGeneration" != "$persistentGeneration'' publication.data
      && lib.hasInfix ''oldGeneration" != "$selectedGeneration'' publication.data;
    test-generations-are-not-published =
      lib.hasInfix ''profileGeneration" != "$newGenPath'' publication.data
      && lib.hasInfix "not publishing a Home Manager test generation" publication.data;
    current-target-is-relative =
      lib.hasInfix ''"generations/$generationId/home-storage-policy"'' publication.data
      && !lib.hasInfix ''ln -s "$persistentGeneration" "$next"'' publication.data
      && !lib.hasInfix "ln -s /nix/store" publication.data;
    generation-collisions-are-refused =
      lib.hasInfix "refusing generation ID collision" publication.data
      && lib.hasInfix ''readlink -e "$persistentGeneration"'' publication.data;
    existing-paths-are-migrated = lib.hasInfix "migrating unmanaged path" activation;
    publication-follows-effectful-activation = lib.all (name: lib.elem name publication.after) (
      [ "homeStoragePolicy" ] ++ actual.homeStorage.publishAfter
    );
    generation-contains-boot-artifacts =
      lib.hasInfix "$out/home-storage-policy" actual.home.extraBuilderCommands
      && lib.hasInfix "$out/boot-replay" actual.home.extraBuilderCommands;
    built-in-publication-is-disabled = !actual.home.activationGenerateGcRoot;
    activation-has-temporary-gc-root = lib.hasInfix ''--add-root "$newGenGcPath"'' actual.home.activation.protectHomeStorageGeneration.data;
    user-service-paths-are-resolved = lib.all (
      command: lib.hasInfix "/home/emre/" command && !lib.hasInfix "$HOME" command
    ) userServiceCommands;
    no-daemon-client =
      !lib.hasInfix "home-storagectl" activation
      && !lib.hasInfix "D-Bus" activation
      && !lib.hasInfix "home-layout" activation;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "home-storage-policy"
  {
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
  }
  ''
    if [ "$failureCount" != 0 ]; then
      echo "failed user-0 home-storage policy checks: $failureNames" >&2
      exit 1
    fi
    touch "$out"
  ''
