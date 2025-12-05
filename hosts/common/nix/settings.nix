{
  lib,
  pkgs,
  allowUnfree ? true,
  cudaSupport ? false,
  rocmSupport ? false,
  username ? throw "you must specify a username",
  extraSubstituters ? [ ],
  extraTrustedPublicKeys ? [ ],
  maxJobs ? 16,
  nixCores ? 16,
  maxSubstitutionJobs ? 64,
  ...
}:
{
  nixpkgs.config = {
    inherit allowUnfree cudaSupport rocmSupport;

    allowUnfreePredicate = pkgs.lib.mkIf allowUnfree (
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
        username
      ];

      # https://github.com/NixOS/nix/issues/11728
      download-buffer-size = 8 * 1024 * 1024 * 1024; # 8GB

      substituters = [
        "https://cache.nixos.org/"
        "https://ai.cachix.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://numtide.cachix.org"
        "http://100.64.0.1:5101"
      ]
      ++ extraSubstituters;

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "binary-cache-key:YUqGpOpjoO0zIREJVH0PAdjy9L3DWi917Z8/eFqQqy8="
      ]
      ++ extraTrustedPublicKeys;

      max-jobs = maxJobs;
      cores = nixCores;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;

      keep-outputs = true;
      keep-derivations = true;

      fallback = true;
      connect-timeout = 5;

      max-substitution-jobs = maxSubstitutionJobs;
    };
  };
}
