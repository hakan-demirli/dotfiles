{
  lib,
  inputs,
  opencode,
  profile,
  facts,
  pkgs,
  ...
}:
let
  personal = (import ../../common/lib.nix).allowsPersonalData facts;
  inherit (inputs.self.lib) forge inventory;
  stateRemote = forge.remote "state";
in
{
  imports = [
    ../../common/default.nix
    (../../common/profiles + "/${profile}.nix")
    ../../common/modules/sops.nix
    (import ../../common/pkgs/nix/opencode.nix opencode)
  ]
  ++ lib.optionals personal [
    ../../common/pkgs/nix/pi.nix
    (import ../../common/pkgs/nix/state_backup.nix {
      remote = stateRemote;
      logBranch = "hosts/${facts.id}";
    })
  ]
  ++ lib.optionals (personal && profile == "desktop") [
    ./wallpaper.nix
    (import ../../common/pkgs/nix/ntfy-listener.nix { })
    (import ../../common/pkgs/nix/github_backup.nix { })
    (import ../../common/pkgs/nix/notes_backup.nix {
      remote = stateRemote;
      branch = "nocon";
    })
  ]
  ++ lib.optionals (personal && lib.elem facts.id inventory.services.forgejo.hosts) [
    (import ../../common/pkgs/nix/github_mirrors.nix {
      inherit (forge) owner;
      forge = forge.web;
      excluded = [ "state" ];
    })
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
    ++ lib.optional personal "sops-nix";
    paths = {
      ".cache" = "persistent";
      ".local/share/direnv" = "persistent";
      Desktop = "persistent";
      Documents = "persistent";
      Downloads = "persistent";
      Videos = "persistent";
    }
    // lib.optionalAttrs personal {
      ".config/mozilla" = "persistent";
      ".config/pi" = "persistent";
      ".config/sops/age" = "persistent";
      ".local/share/state" = "persistent";
      ".local/share/opencode" = "persistent";
      ".local/state/bash" = "persistent";
      ".local/state/exodia" = "persistent";
      ".local/state/opencode" = "persistent";
      ".local/state/pi" = "persistent";
      ".local/state/wireplumber" = "persistent";
    };
  };
}
