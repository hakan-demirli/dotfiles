{ pkgs, ... }:
{
  services.github-runners-urlFile.runner0 = {
    enable = true;

    urlFile = "/persist/home/emre/Desktop/state/github-runners/url0";
    tokenFile = "/persist/home/emre/Desktop/state/github-runners/token0";

    user = "emre";
    group = "users";

    ephemeral = true;
    replace = true;
    name = "runner0";
    extraLabels = [
      "self-hosted"
      "x86-64"
      "nix"
    ];

    extraPackages = [ pkgs.nix ];

    extraEnvironment = {
      NIX_REMOTE = "daemon";
    };
  };

  nix.settings.trusted-users = [
    "root"
    "emre"
  ];
}
