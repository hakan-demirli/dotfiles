{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    inputs.nixpkgs.lib.optionalAttrs (inputs.nixpkgs.lib.strings.hasSuffix "-linux" system) {
      packages.kexec =
        (inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (inputs.self + /pkgs/kexec/configuration.nix)
          ];
        }).config.system.build.kexec_bundle
        // {
          meta.description = "kexec bundle for NixOS";
        };
    };
}
