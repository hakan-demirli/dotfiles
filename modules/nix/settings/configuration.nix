{
  flake.modules.nixos.nix-settings =
    {
      config,
      lib,
      ...
    }:
    {
      options.nix.custom = {
        allowUnfree = lib.mkEnableOption "allow unfree";
        cudaSupport = lib.mkEnableOption "cuda support";
        rocmSupport = lib.mkEnableOption "rocm support";
        hasNvidia = lib.mkEnableOption "host has NVIDIA GPU (enables cuda-maintainers cachix)";
        hasTailscaleAuthority = lib.mkEnableOption "host has full tailscale authority and sops (enables tailnet substituters)";
        username = lib.mkOption {
          type = lib.types.str;
          default = config.system.user.username;
          description = "Username for nix trusted-users";
        };
        excludeSubstituters = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Substituters to exclude (e.g., to avoid self-substitution)";
        };
      };

      config = {
        nixpkgs.config = {
          inherit (config.nix.custom) allowUnfree;
          inherit (config.nix.custom) cudaSupport;
          inherit (config.nix.custom) rocmSupport;

          allowUnfreePredicate = lib.mkIf config.nix.custom.allowUnfree (
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

            substituters =
              let
                base = [
                  "https://cache.nixos.org?priority=10"
                  "https://nix-community.cachix.org"
                ];
                nvidia = lib.optionals config.nix.custom.hasNvidia [
                  "https://ai.cachix.org"
                  "https://cuda-maintainers.cachix.org"
                  "https://numtide.cachix.org"
                ];
                tailnet = lib.optionals config.nix.custom.hasTailscaleAuthority [
                  "http://100.64.0.1:5101?priority=60"
                ];
              in
              builtins.filter (
                s:
                !(lib.lists.any (excluded: lib.strings.hasInfix excluded s) config.nix.custom.excludeSubstituters)
              ) (base ++ nvidia ++ tailnet);

            trusted-public-keys =
              let
                base = [
                  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
                nvidia = lib.optionals config.nix.custom.hasNvidia [
                  "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
                  "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
                  "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
                ];
                tailnet = lib.optionals config.nix.custom.hasTailscaleAuthority [
                  "binary-cache-key:YUqGpOpjoO0zIREJVH0PAdjy9L3DWi917Z8/eFqQqy8="
                ];
              in
              base ++ nvidia ++ tailnet;

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
