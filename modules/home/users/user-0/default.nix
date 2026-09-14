{
  lib,
  opencode,
  profile,
  facts,
  pkgs,
  ...
}:
let
  personal = (import ../../common/lib.nix).allowsPersonalData facts;
in
{
  imports = [
    ../../common/default.nix
    (../../common/profiles + "/${profile}.nix")
    ../../common/modules/sops.nix
    (import ../../common/pkgs/nix/opencode.nix opencode)
  ]
  ++ lib.optionals personal [
    (import ../../common/pkgs/nix/state_backup.nix {
      remote = "https://github.com/hakan-demirli/state";
      logBranch = if profile == "desktop" then "nocon" else "hosts/${facts.id}";
    })
  ]
  ++ lib.optionals (personal && profile == "desktop") [
    ./wallpaper.nix
    (import ../../common/pkgs/nix/ntfy-listener.nix { })
    (import ../../common/pkgs/nix/github_backup.nix { })
  ];

  home = rec {
    username = "emre";
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  homeSops.identity = "user-0";
  homeSops.enable = personal;

  home.activation.checkHostIdentity = lib.mkIf (facts ? ownership) (
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      actualHost="$(${pkgs.inetutils}/bin/hostname -s)"
      if [[ "$actualHost" != ${lib.escapeShellArg facts.id} ]]; then
        echo "Home Manager target ${facts.id} does not match $actualHost" >&2
        exit 1
      fi
    ''
  );

  homeStorage = {
    enable = true;
    default = "temporary";
    publishAfter = [
      "nixTailnetCache"
      "reloadSystemd"
    ]
    ++ lib.optional personal "removeGitTokenUrlRewrite";
    paths = {
      ".cache" = "persistent";
      Desktop = "persistent";
      Documents = "persistent";
      Downloads = "persistent";
      Videos = "persistent";
    }
    // lib.optionalAttrs personal {
      ".config/mozilla" = "persistent";
      ".config/sops/age" = "persistent";
      ".local/share/state" = "persistent";
      ".local/share/opencode" = "persistent";
      ".local/state/opencode" = "persistent";
      ".local/state/wireplumber" = "persistent";
    };
  };
}
