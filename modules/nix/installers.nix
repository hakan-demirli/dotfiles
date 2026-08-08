{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inventory = inputs.self.lib.inventory;
      eligibleHosts = lib.filterAttrs (
        hostId: host:
        host.hardware.os == "linux"
        && host.hardware.arch == system
        && host.disko != null
        && host.disko.managed
        && host.disko.installer.enable
        && builtins.hasAttr hostId inputs.self.nixosConfigurations
      ) inventory.hosts;

      mkBundle =
        hostId: host:
        let
          systemBuild = inputs.self.nixosConfigurations.${hostId}.config.system.build;
          bundle = inputs.infra-lib.lib.mkDiskoInstallerBundle {
            inherit inputs system;
            inherit hostId;
            rootKeys = inputs.self.lib.kexecRootKeys;
            expectedDisk = host.disko.root_disk;
            targetSystem = systemBuild.toplevel;
            inherit (systemBuild) diskoScript;
          };
        in
        bundle
        // {
          meta = (bundle.meta or { }) // {
            description = "Self-contained destructive installer for ${hostId}";
          };
        };

      bundles = lib.mapAttrs mkBundle eligibleHosts;
      packageOutputs = lib.mapAttrs' (
        hostId: bundle: lib.nameValuePair "install-${hostId}" bundle
      ) bundles;
      appOutputs = lib.mapAttrs' (
        hostId: bundle:
        let
          expectedDisk = eligibleHosts.${hostId}.disko.root_disk;
          launcher = pkgs.writeShellApplication {
            name = "install-${hostId}";
            runtimeInputs = [ pkgs.sudo ];
            text = ''
              expected_disk=${lib.escapeShellArg expectedDisk}

              if [[ ! -b "$expected_disk" ]]; then
                echo "refusing install: expected disk not found: $expected_disk" >&2
                exit 1
              fi

              echo "This will irreversibly erase $expected_disk and install ${hostId}."
              read -r -p "Type 'WIPE ${hostId}' to continue: " confirmation
              if [[ "$confirmation" != "WIPE ${hostId}" ]]; then
                echo "installation cancelled" >&2
                exit 1
              fi

              if (( EUID == 0 )); then
                exec ${bundle}
              fi
              exec sudo -- ${bundle}
            '';
          };
        in
        lib.nameValuePair "install-${hostId}" {
          type = "app";
          program = "${launcher}/bin/install-${hostId}";
          meta.description = "Confirm and launch the destructive installer for ${hostId}";
        }
      ) bundles;
    in
    {
      packages = packageOutputs;
      apps = appOutputs;
    };
}
