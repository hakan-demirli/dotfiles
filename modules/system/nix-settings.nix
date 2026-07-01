{
  config,
  lib,
  host ? null,
  ...
}:
let
  cfg = config.nix.custom;

  hwGpu = if host == null then null else (host.hardware.gpu or null);
  hasNvidiaFromInventory = hwGpu != null && (builtins.match ".*nvidia.*" hwGpu) != null;

  labels = if host == null then { } else (host.labels or { });
  hasTailscaleAuthorityFromInventory = (labels.tailscale_authority or "false") == "true";
in
{
  options.nix.custom = {
    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow unfree packages.";
    };
    cudaSupport = lib.mkEnableOption "CUDA support in nixpkgs.config";
    rocmSupport = lib.mkEnableOption "ROCm support in nixpkgs.config";
    hasNvidia = lib.mkOption {
      type = lib.types.bool;
      default = hasNvidiaFromInventory;
      description = ''
        Host has an NVIDIA GPU. Enables cuda-maintainers / ai / numtide
        cachix substituters. Defaults to true when host.hardware.gpu
        contains "nvidia".
      '';
    };
    hasTailscaleAuthority = lib.mkOption {
      type = lib.types.bool;
      default = hasTailscaleAuthorityFromInventory;
      description = ''
        Host has full authority on the personal tailnet -- i.e. it can
        reach the tailnet binary cache at 100.64.0.1:5101. Defaults to
        true when host.labels.tailscale_authority == "true".
      '';
    };
    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "root" ];
      description = ''
        Extra trusted users (added on top of "root"). cluster-users.nix
        already grants individual humans access; this option is for any
        non-inventory users that should be trusted for nix daemon ops.
      '';
    };
    excludeSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Substring filter applied to the substituter URL list. Use to
        avoid self-substitution on the host that runs the cache server.
      '';
    };
  };

  config = {
    nixpkgs.config = {
      inherit (cfg) allowUnfree cudaSupport rocmSupport;

      allowUnfreePredicate = lib.mkIf cfg.allowUnfree (
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
        trusted-users = lib.unique ([ "root" ] ++ cfg.trustedUsers);

        download-buffer-size = 8 * 1024 * 1024 * 1024;

        substituters =
          let
            base = [
              "https://cache.nixos.org?priority=10"
              "https://nix-community.cachix.org"
            ];
            nvidia = lib.optionals cfg.hasNvidia [
              "https://ai.cachix.org"
              "https://cuda-maintainers.cachix.org"
              "https://numtide.cachix.org"
            ];
            tailnet = lib.optionals cfg.hasTailscaleAuthority [
              "http://100.64.0.1:5101?priority=60"
            ];
          in
          lib.filter (
            s: !(lib.lists.any (excluded: lib.strings.hasInfix excluded s) cfg.excludeSubstituters)
          ) (base ++ nvidia ++ tailnet);

        trusted-public-keys =
          let
            base = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
            nvidia = lib.optionals cfg.hasNvidia [
              "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
              "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
              "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
            ];
            tailnet = lib.optionals cfg.hasTailscaleAuthority [
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
}
