{ inputs, lib, ... }:
let
  platforms = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-15";
  };
  portableSystem = "x86_64-linux";
  costs = [
    "heavy"
    "light"
  ];

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
  costOf = trait "ciCost" costs "light";

  checks = lib.mapAttrs (
    system: lib.filterAttrs (name: _: scopeOf system name == "native" || system == portableSystem)
  ) inputs.self.checks;

  jobs = inputs.nix-github-actions.lib.mkGithubMatrix { inherit checks platforms; };

  inherit (inputs.self.lib) inventory;
  ciHost = lib.head inventory.services.nixbot.hosts;
  archOf = id: inventory.hosts.${id}.hardware.arch;
  ciSystems = lib.unique (map archOf ([ ciHost ] ++ inventory.hostsByDeploymentRole.server-dev));
  ciPkgs = inputs.nixpkgs.legacyPackages.${archOf ciHost};
  effects = inputs.nixbot.lib.effects { pkgs = ciPkgs; };

  runnable = system: inputs.self.legacyPackages.${system}.externalBuilds or { };
  external = inputs.nix-github-actions.lib.mkGithubMatrix {
    checks = lib.mapAttrs (
      system: packages: packages.deviceBuilds or { } // runnable system
    ) inputs.self.legacyPackages;
    attrPrefix = "githubActions.external.checks";
    platforms = platforms // {
      x86_64-linux = "ubuntu-22.04";
    };
  };
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
          outputs.effects.update = effects.flakeUpdate {
            forgeType = "gitea";
            updateBranch = "automation/update-flake-inputs";
            autoMergeMethod = "rebase";
            pullRequestTitle = "chore: update flake inputs";
            commitSummary = "chore: update flake inputs";
          };
        };
      };

    githubActions = jobs // {
      matrix.include = lib.concatMap (
        cost: lib.filter (entry: costOf entry.system entry.name == cost) jobs.matrix.include
      ) costs;

      external = external // {
        matrix.include = map (
          entry:
          entry
          // {
            mode = if runnable entry.system ? ${entry.name} then "run" else "build";
          }
        ) external.matrix.include;
      };
    };
  };
}
