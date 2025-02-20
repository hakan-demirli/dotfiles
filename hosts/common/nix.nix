{
  threads ? throw "Set number of threads, e.g. 16",
  ...
}:
{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      substituters = [
        "https://ai.cachix.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://numtide.cachix.org"
      ];
      trusted-public-keys = [
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];

      max-jobs = threads;
      cores = threads;
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      # use-xdg-base-directories = true; # https://github.com/nix-community/home-manager/issues/5805

      # Prevent garbage collection from altering nix-shells managed by nix-direnv
      # https://github.com/nix-community/nix-direnv#installation
      keep-outputs = true;
      keep-derivations = true;
      # perf
      max-substitution-jobs = threads * 16; # WARNING: Magic Number
    };
  };
}
