{
  pkgs,
  config,
  userSettings,
  ...
}:
{
  xdg =
    let
      mutable_configs = [
        ".bash_history"
        "hypr"
        "rvc-cli"
        "mimeapps.list"
        "rclone"
      ];

      immutable_configs = [
        "activitywatch"
        "anyrun"
        "awatcher"
        "bat"
        "btop"
        "cargo"
        "firefoxcss"
        "git"
        "gnome3-keybind-backup"
        "gnome-extensions"
        "gtk_indicator"
        "helix"
        "input-remapper-2"
        "kitty"
        "lf"
        "mpd"
        "mpv"
        "mylib"
        "nix"
        "npm"
        "nwg"
        "parallel"
        # "piper" # not working, workaround below
        "qmk"
        "quantifyself"
        "quantifyself-webui"
        "qutebrowser"
        "rmpc"
        "sioyek"
        "starship.toml"
        "swaync"
        "task"
        "timewarrior"
        "tmux"
        "tmuxp"
        "tofi"
        "udiskie"
        "vim"
        "wavemon"
        "waybar"
        "wgetrc"
        "wofi"
        "xremap"
        "yazi"
        "zathura"
        "zsh"
      ];

      immutable_data = [
        "applications"
        "fonts"
      ];
      mutable_data = [
      ];

      makeMutable = path: file: {
        target = file;
        source = config.lib.file.mkOutOfStoreSymlink "${userSettings.dotfilesDir}/${path}/${file}";
        recursive = true;
      };

      makeImmutable = path: file: {
        target = file;
        source = ../../${path}/${file};
        recursive = true;
      };

      mutableConfigFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeMutable ".config" file;
        }) mutable_configs
      );

      immutableConfigFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeImmutable ".config" file;
        }) immutable_configs
      );

      mutableDataFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeMutable ".local/share" file;
        }) mutable_data
      );

      immutableDataFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeImmutable ".local/share" file;
        }) immutable_data
      );
    in
    {
      configFile = mutableConfigFiles // immutableConfigFiles;
      dataFile = mutableDataFiles // immutableDataFiles;

      portal = {
        enable = true;
        xdgOpenUsePortal = true;
        config = {
          common = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
            "org.freedesktop.impl.portal.GlobalShortcuts" = [ "hyprland" ];
            # "org.freedesktop.impl.portal.FileChooser" = [
            #   "termfilechooser"
            # ]; # not working
          };
          hyprland.default = [
            "hyprland"
            "gtk"
          ];
          # hyprland.default = ["hyprland" "termfilechooser" "gtk"]; # not working
        };

        extraPortals = [
          # (pkgs.callPackage ../../system/app/xdg-desktop-portal-termfilechooser.nix {}) # not working
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-wlr
          pkgs.xdg-desktop-portal-hyprland
        ];
      };
    };
  home.file.".local/bin" = {
    source = ../../.local/bin;
    recursive = true;
    executable = true;
  };

  home.file.".local/share/sounds" = {
    source = config.lib.file.mkOutOfStoreSymlink "${userSettings.gdriveDir}/sounds";
    recursive = true;
    executable = false;
  };

  home.file.".local/share/scratchpads" = {
    source = config.lib.file.mkOutOfStoreSymlink "${userSettings.gdriveDir}/scratchpads";
    recursive = true;
    executable = false;
  };

  home.file.".config/notify-scheduler" = {
    source = config.lib.file.mkOutOfStoreSymlink "${userSettings.gdriveDir}/software/notify-scheduler";
    recursive = true;
    executable = false;
  };

  home.file.".thunderbird/personal/ImapMail/imap.gmail.com/msgFilterRules.dat" = {
    source = ../../.config/mylib/msgFilterRules.dat;
    recursive = false;
    executable = false;
  };

  home.file.".config/rvc-cli/rvc/models/embedders/contentvec/pytorch_model.bin".source = "${
    pkgs.fetchurl
    {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/pytorch_model.bin";
      sha256 = "sha256-2N1ADgVN305r512rWiVJ23SMyZ51agl8SWwJn2WkhU4=";
    }
  }";
  home.file.".config/rvc-cli/rvc/models/embedders/contentvec/config.json".source = "${pkgs.fetchurl {
    url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/config.json";
    sha256 = "sha256-Ld3gY7eV042QUachWgkv7PTP4Ui1QlHjjeUdiNNWiYs=";
  }}";
  home.file.".config/rvc-cli/models/predictors/rmvpe.pt".source = "${pkgs.fetchurl {
    url = "https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.pt";
    sha256 = "sha256-bWIhX0MG48ongkYYhgcgnwmvPcd+1CMu/dBpeYxOwZM=";
  }}";
  home.file.".config/rvc-cli/models/custom/".source = "${pkgs.fetchzip {
    url = "https://huggingface.co/PGR-RVC/NieR_RVC_v2/resolve/main/EN/Pod042EN_e250_s14250_RVCv2_RMVPE.zip";
    sha256 = "sha256-PGPCG5FwsoPGE6PGtYTBuE3fan1JTj95d5J3b77GLxg=";
    stripRoot = false;
  }}";
  home.file.".config/piper/models/jenny_dioco.onnx".source = "${pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx";
    sha256 = "sha256-RpxjDSCeE53TkqZr9KveSrhjkKAmnB5HtOXXzoFSawE=";
  }}";
  home.file.".config/piper/models/jenny_dioco.json".source = "${pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json";
    sha256 = "sha256-qaepOjF8mjy2Vj436wV9+e8JwGGIqKQ0Gw/LWMulTdQ=";
  }}";
  home.file.".config/piper/substitutions.json".source = "${../../.config/piper/substitutions.json}"; # workaround
}
