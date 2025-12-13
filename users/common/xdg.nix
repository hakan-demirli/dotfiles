{
  pkgs,
  desktopDir ? throw "Set this to your state dir",
  ...
}:
{
  xdg =
    let
      mutable_configs = [
        # "hypr"
        # "rclone"
        "rvc-cli"
      ];

      immutable_configs = [
        "activitywatch"
        "aichat"
        "aider"
        "anyrun"
        "awatcher"
        "wayscriber"
        "bat"
        "bash"
        "btop"
        "cargo"
        "clangd"
        "firefoxcss"
        "gdb"
        "gdb-dashboard"
        "git"
        "gnome3-keybind-backup"
        "gnome-extensions"
        "gtk_indicator"
        "helix"
        "hypr"
        "input-remapper-2"
        "kitty"
        "lf"
        "mimeapps.list"
        "mpd"
        "mpv"
        "nix"
        "npm"
        "nwg"
        "opencode"
        "parallel"
        # "piper" # not working, workaround below
        "qalculate"
        "qmk"
        "QtProject"
        "quantifyself"
        # "quantifyself-webui"
        "qutebrowser"
        "repx"
        "rmpc"
        "sioyek"
        "starship.toml"
        "swaync"
        # "task"
        # "timewarrior"
        "tmux"
        "tmuxp"
        "tofi"
        "transmission"
        "vim"
        "wavemon"
        "waybar"
        "wgetrc"
        "wofi"
        "xdg-desktop-portal-termfilechooser"
        "xilinx"
        "xremap"
        "yazi"
        "zathura"
        "zsh"
      ];

      immutable_data = [
        "applications"
      ];

      mutable_data = [
      ];

      mutable_state = [
        # link from gdriveDir
        # "bash"
        # "gdb"
      ];
      # no such attribute file: config.lib.file.mkOutOfStoreSymlink
      #
      makeMutable = path: file: {
        target = file;
        source = pkgs.runCommand "${file}-dotfiles" { } ''
          ln -s "${desktopDir}/dotfiles/${path}/${file}" $out
        '';
        # source = pkgs.linkFarm "${file}-dotfiles" [
        #   {
        #     name = file;
        #     path = "${dotfilesDir}/${path}/${file}";
        #   }
        # ];
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

      mutableStateFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeMutable ".local/state" file;
        }) mutable_state
      );

      immutableDataFiles = builtins.listToAttrs (
        map (file: {
          name = file;
          value = makeImmutable ".local/share" file;
        }) immutable_data
      );
    in
    {
      configFile =
        mutableConfigFiles
        // immutableConfigFiles
        // {
          "hypr/monitors.conf" = {
            source = ../../.config/hypr/monitors.conf;
            force = true;
          };
        };

      dataFile = mutableDataFiles // immutableDataFiles;
      stateFile = mutableStateFiles;
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
          hyprland = {
            "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
            default = [
              "hyprland"
              "gtk"
            ];
          };
        };
        extraPortals = [
          pkgs.xdg-desktop-portal-termfilechooser
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-wlr
          pkgs.xdg-desktop-portal-hyprland
        ];
      };
    };

  home.file = {
    ".local/bin" = {
      source = ../../.local/bin;
      recursive = true;
      executable = true;
    };
    ".aider.conf.yml" = {
      source = ../../.config/aider/.aider.conf.yml;
    };
    ".local/state" = {
      source = pkgs.linkFarm "gdrive-links" [
        {
          name = "bash";
          path = "${desktopDir}/state/.local/state/bash";
        }
        {
          name = "gdb";
          path = "${desktopDir}/state/.local/state/gdb";
        }
        {
          name = "qalculate";
          path = "${desktopDir}/state/.local/state/qalculate";
        }
      ];
      recursive = true;
      executable = false;
    };
    ".local/share" = {
      source = pkgs.linkFarm "gdrive-links" [
        {
          name = "sounds";
          path = "${desktopDir}/sounds";
        }
        {
          name = "scratchpads";
          path = "${desktopDir}/state/scratchpads";
        }
        {
          name = "notify-scheduler";
          path = "${desktopDir}/gdrive/software/notify-scheduler";
        }
        {
          name = "quantifyself";
          path = "${desktopDir}/gdrive/archives/quantifyself";
        }
        {
          name = "homepage";
          path = "${desktopDir}/gdrive/software/homepage";
        }
      ];
      recursive = true;
      executable = false;
    };
    ".local/share/fonts" = {
      source = pkgs.fetchFromGitHub {
        owner = "dv-anomaly";
        repo = "ttf-wps-fonts";
        rev = "8c980c24289cb08e03f72915970ce1bd6767e45a";
        sha256 = "sha256-x+grMnpEGLkrGVud0XXE8Wh6KT5DoqE6OHR+TS6TagI=";
      };
      recursive = true;
      executable = false;
    };
    # ".thunderbird/personal/ImapMail/imap.gmail-1.com/msgFilterRules.dat" = {
    #   source = ../../secrets/msgFilterRules.dat;
    #   recursive = false;
    #   executable = false;
    # };
    ".config/rvc-cli/rvc/models/embedders/contentvec/pytorch_model.bin".source = "${pkgs.fetchurl {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/pytorch_model.bin";
      sha256 = "sha256-2N1ADgVN305r512rWiVJ23SMyZ51agl8SWwJn2WkhU4=";
    }}";
    ".config/rvc-cli/rvc/models/embedders/contentvec/config.json".source = "${pkgs.fetchurl {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/config.json";
      sha256 = "sha256-Ld3gY7eV042QUachWgkv7PTP4Ui1QlHjjeUdiNNWiYs=";
    }}";
    ".config/rvc-cli/models/predictors/rmvpe.pt".source = "${pkgs.fetchurl {
      url = "https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.pt";
      sha256 = "sha256-bWIhX0MG48ongkYYhgcgnwmvPcd+1CMu/dBpeYxOwZM=";
    }}";
    ".config/rvc-cli/models/custom/".source = "${pkgs.fetchzip {
      url = "https://huggingface.co/PGR-RVC/NieR_RVC_v2/resolve/main/EN/Pod042EN_e250_s14250_RVCv2_RMVPE.zip";
      sha256 = "sha256-PGPCG5FwsoPGE6PGtYTBuE3fan1JTj95d5J3b77GLxg=";
      stripRoot = false;
    }}";
    ".config/piper/models/jenny_dioco.onnx".source = "${pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx";
      sha256 = "sha256-RpxjDSCeE53TkqZr9KveSrhjkKAmnB5HtOXXzoFSawE=";
    }}";
    ".config/piper/models/jenny_dioco.json".source = "${pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json";
      sha256 = "sha256-qaepOjF8mjy2Vj436wV9+e8JwGGIqKQ0Gw/LWMulTdQ=";
    }}";
    ".config/piper/substitutions.json".source = "${../../.config/piper/substitutions.json}"; # workaround
  };
}
