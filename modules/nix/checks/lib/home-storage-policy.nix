{
  pkgs,
  self,
  lib,
  inputs,
}:
let
  homes = {
    desktop = self.homeConfigurations."emre@laptop-1";
    desktop-nvidia = self.homeConfigurations."emre@laptop-0";
    headless = self.homeConfigurations."emre@server-dev-1";
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
    ".config/pi" = "persistent";
    ".config/sops/age" = "persistent";
    ".local/share/direnv" = "persistent";
    ".local/share/opencode" = "persistent";
    ".local/share/state" = "persistent";
    ".local/state/bash" = "persistent";
    ".local/state/opencode" = "persistent";
    ".local/state/pi" = "persistent";
    ".local/state/wireplumber" = "persistent";
    Desktop = "persistent";
    Documents = "persistent";
    Downloads = "persistent";
    Videos = "persistent";
  };
  actual = homes.desktop.config;
  publication = actual.home.activation.publishHomeStorageGeneration;
  storageEntries = [
    "checkHomeStorage"
    "applyHomeStorage"
    "publishHomeStorageGeneration"
  ];
  activationOrder =
    home:
    let
      activation = home.config.home.activation;
      names = map (entry: entry.name) (inputs.home-manager.lib.hm.dag.topoSort activation).result;
      at = name: lib.lists.findFirstIndex (candidate: candidate == name) null names;
      precedes = first: second: at first < at second;
      references = lib.concatMap (
        name: activation.${name}.before ++ activation.${name}.after
      ) storageEntries;
    in
    lib.all (name: activation ? ${name}) storageEntries
    && lib.all (name: activation ? ${name}) references
    && precedes "checkHomeStorage" "writeBoundary"
    && precedes "writeBoundary" "applyHomeStorage"
    && precedes "applyHomeStorage" "linkGeneration"
    && lib.all (
      name: precedes name "publishHomeStorageGeneration"
    ) activation.publishHomeStorageGeneration.after;
  userServiceCommands =
    map (name: builtins.head actual.systemd.user.services.${name}.Service.ExecStart)
      [
        "github-backup"
        "notes-backup"
        "ntfy-listener"
        "state-backup"
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
    storage-is-checked-before-writes-and-applied-before-links = lib.all activationOrder (
      lib.attrValues self.homeConfigurations
    );
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
    publication-follows-effectful-activation = lib.all (name: lib.elem name publication.after) (
      [
        "applyHomeStorage"
        "installPackages"
      ]
      ++ actual.homeStorage.publishAfter
    );
    publication-leaves-gc-roots-to-home-manager = lib.all (name: !lib.hasInfix name publication.data) [
      "newGenGcPath"
      "currentGenGcPath"
      "legacyGenGcPath"
    ];
    generation-contains-boot-artifacts =
      lib.hasInfix "$out/home-storage-policy" actual.home.extraBuilderCommands
      && lib.hasInfix "$out/boot-replay" actual.home.extraBuilderCommands;
    user-service-paths-are-resolved = lib.all (
      command: lib.hasInfix "/home/emre/" command && !lib.hasInfix "$HOME" command
    ) userServiceCommands;
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
