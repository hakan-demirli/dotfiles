{ inputs, lib, ... }:
let
  portableSystem = "x86_64-linux";

  trait =
    attribute: allowed: default: system: name:
    let
      value = inputs.self.checks.${system}.${name}.${attribute} or default;
    in
    if lib.elem value allowed then
      value
    else
      throw "checks.${system}.${name}.${attribute} is ${builtins.toJSON value}, expected one of: ${lib.concatStringsSep ", " allowed}";

  scopeOf = trait "ciScope" [
    "native"
    "portable"
  ] "native";

  checks = lib.mapAttrs (
    system: lib.filterAttrs (name: _: scopeOf system name == "native" || system == portableSystem)
  ) inputs.self.checks;

  inherit (inputs.self.lib) inventory;
  ciHost = lib.head inventory.services.nixbot.hosts;
  archOf = id: inventory.hosts.${id}.hardware.arch;
  ciSystems = lib.unique (map archOf ([ ciHost ] ++ inventory.hostsByDeploymentRole.server-dev));
  ciPkgs = inputs.nixpkgs.legacyPackages.${archOf ciHost};
  effects = inputs.nixbot.lib.effects { pkgs = ciPkgs; };
  inherit (inputs.self.lib.forge.identities) bot;
in
{
  flake = {
    hydraJobs = {
      checks = lib.genAttrs ciSystems (system: checks.${system} or { });
      devices = lib.genAttrs (lib.intersectLists ciSystems (lib.attrNames inputs.self.legacyPackages)) (
        system:
        let
          packages = inputs.self.legacyPackages.${system};
        in
        packages.deviceBuilds or { } // packages.externalBuilds or { }
      );
    };

    herculesCI =
      { primaryRepo, ... }:
      {
        onPush.default.outputs.effects = lib.optionalAttrs (primaryRepo.branch == "unstable") {
          promote-main = effects.mkEffect {
            name = "promote-main";
            checkout = true;
            lock = "promote-main";
            inputs = [ ciPkgs.git ];
            effectScript = ''
              set -euo pipefail
              candidate=${primaryRepo.rev}
              main=$(git ls-remote --exit-code origin refs/heads/main | cut -f1)
              unstable=$(git ls-remote --exit-code origin refs/heads/unstable | cut -f1)
              git fetch --quiet --no-tags origin "$main" "$unstable"
              if git merge-base --is-ancestor "$candidate" "$main"; then
                echo "$candidate is already on main"
                exit 0
              fi
              git merge-base --is-ancestor "$main" "$candidate"
              git merge-base --is-ancestor "$candidate" "$unstable"
              git push origin "$candidate:refs/heads/main"
            '';
          };
        };

        onSchedule.update-flake-inputs = {
          when = {
            hour = 7;
            minute = 17;
          };
          outputs.effects.update =
            (effects.flakeUpdate {
              forgeType = "gitea";
              updateBranch = "automation/update-flake-inputs";
              # Each run starts over from the channel instead of reusing a stale branch.
              baseMergeBranch = "unstable";
              baseMergeMethod = "reset";
              autoMergeMethod = "fast-forward-only";
              pullRequestTitle = "chore: update flake inputs";
              commitSummary = "chore: update flake inputs";
            }).overrideAttrs
              {
                GIT_AUTHOR_NAME = bot.name;
                GIT_AUTHOR_EMAIL = bot.email;
                GIT_COMMITTER_NAME = bot.name;
                GIT_COMMITTER_EMAIL = bot.email;
              };
        };
      };
  };
}
