{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages.kexec =
        (inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (inputs.self + /pkgs/kexec/configuration.nix)
          ];
        }).config.system.build.kexec_bundle;
    };
}
