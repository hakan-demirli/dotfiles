{
  flake.modules.nixos.nix-settings =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.nix.custom = {
        allowUnfree = lib.mkEnableOption "allow unfree";
        cudaSupport = lib.mkEnableOption "cuda support";
        rocmSupport = lib.mkEnableOption "rocm support";
        username = lib.mkOption { type = lib.types.str; };
      };

      config = {
        nixpkgs.config = {
          inherit (config.nix.custom) allowUnfree;
          inherit (config.nix.custom) cudaSupport;
          inherit (config.nix.custom) rocmSupport;

          allowUnfreePredicate = pkgs.lib.mkIf config.nix.custom.allowUnfree (
            p:
            builtins.all (
              license:
              license.free
              || builtins.elem (license.shortName or "unknown") [
                "CUDA EULA"
                "cuDNN EULA"
                "cuTENSOR EULA"
                "NVidia OptiX EULA"
                "unfree"
              ]
            ) (lib.lists.toList (p.meta.license or [ ]))
          );
        };

        nix = {
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
          };

          settings = {
            trusted-users = [
              "root"
              config.nix.custom.username
            ];

            download-buffer-size = 8 * 1024 * 1024 * 1024;

            substituters = [
              "https://cache.nixos.org/"
              "https://ai.cachix.org"
              "https://nix-community.cachix.org"
              "https://cuda-maintainers.cachix.org"
              "https://numtide.cachix.org"
              "http://100.64.0.1:5101"
            ];

            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
              "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
              "binary-cache-key:YUqGpOpjoO0zIREJVH0PAdjy9L3DWi917Z8/eFqQqy8="
            ];

            experimental-features = [
              "nix-command"
              "flakes"
            ];
            auto-optimise-store = true;
            keep-outputs = true;
            keep-derivations = true;
            fallback = true;
            connect-timeout = 5;
          };
        };
      };
    };
}
