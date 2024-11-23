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
        "mimeapps.list"
      ];

      immutable_configs = [
        "anyrun"
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
        "qmk"
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
        "sounds"
      ];
      mutable_data = [
        "task"
        "timewarrior"
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
}
