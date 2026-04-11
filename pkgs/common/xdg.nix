{
  pkgs,
  desktopDir ? throw "Set this to your state dir",
  enablePortal ? true,
  ...
}:
{
  xdg =
    let
      mutable_configs = [
        # "hypr"
        # "rclone"
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
        "claude"
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
      configFile = mutableConfigFiles // immutableConfigFiles;

      dataFile = mutableDataFiles // immutableDataFiles;
      stateFile = mutableStateFiles;
    }
    // pkgs.lib.optionalAttrs enablePortal {
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
    ".claude/settings.json" = {
      source = ../../.config/claude/settings.json;
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
    # ".thunderbird/personal/ImapMail/imap.gmail-1.com/msgFilterRules.dat" = {
    #   source = ../../secrets/msgFilterRules.dat;
    #   recursive = false;
    #   executable = false;
    # };
  };
}
