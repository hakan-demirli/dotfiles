{ profile, ... }:
{
  imports = [
    ../../common/default.nix
    (../../common/profiles + "/${profile}.nix")
    ../../common/modules/sops.nix
  ];

  home = rec {
    username = "emre";
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  homeSops.identity = "user-0";
}
