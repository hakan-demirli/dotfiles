{ lib, profile, ... }:
{
  imports = [
    ../../common/default.nix
    (../../common/profiles + "/${profile}.nix")
    ../../common/modules/sops.nix
  ]
  ++ lib.optional (profile == "desktop") ./wallpaper.nix;

  home = rec {
    username = "emre";
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  homeSops.identity = "user-0";

  homeStorage = {
    enable = true;
    default = "temporary";
    publishAfter = [
      "nixTailnetCache"
      "reloadSystemd"
      "removeGitTokenUrlRewrite"
    ];
    paths = {
      ".cache" = "persistent";
      ".config/mozilla" = "persistent";
      ".config/sops/age" = "persistent";
      ".local/share/opencode" = "persistent";
      ".local/state/opencode" = "persistent";
      ".local/state/wireplumber" = "persistent";
      Desktop = "persistent";
      Documents = "persistent";
      Downloads = "persistent";
      Videos = "persistent";
    };
  };
}
