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
        "hypr"
        "mimeapps.list"
        ".bash_history"
      ];

      immutable_configs = [
        "bat"
        "anyrun"
        "tofi"
        "qmk"
        "gnome3-keybind-backup"
        "gtk_indicator"
        "kitty"
        "nix"
        "sioyek"
        "udiskie"
        "wofi"
        "btop"
        "gnome-extensions"
        "lf"
        "npm"
        "swaync"
        "vim"
        "xremap"
        "cargo"
        "helix"
        "tmux"
        "wavemon"
        "yazi"
        "firefoxcss"
        "input-remapper-2"
        "mpv"
        "nwg"
        "tmuxp"
        "waybar"
        "zathura"
        "git"
        "mylib"
        "qutebrowser"
        "wgetrc"
        "task"
        "timewarrior"
        "starship.toml"
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
