{
  pkgs,
  config,
  userSettings,
  ...
}: {
  xdg = let
    mutable_configs = ["hypr" "mimeapps.list"];

    immutable_configs = [
      "bat"
      "qmk"
      "gnome3-keybind-backup"
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
      "nvim"
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

    immutable_data = ["applications" "fonts"];
    mutable_data = ["task" "timewarrior"];

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

    mutableConfigFiles = builtins.listToAttrs (map (file: {
        name = file;
        value = makeMutable ".config" file;
      })
      mutable_configs);

    immutableConfigFiles = builtins.listToAttrs (map (file: {
        name = file;
        value = makeImmutable ".config" file;
      })
      immutable_configs);

    mutableDataFiles = builtins.listToAttrs (map (file: {
        name = file;
        value = makeMutable ".local/share" file;
      })
      mutable_data);

    immutableDataFiles = builtins.listToAttrs (map (file: {
        name = file;
        value = makeImmutable ".local/share" file;
      })
      immutable_data);
  in {
    configFile = mutableConfigFiles // immutableConfigFiles;
    dataFile = mutableDataFiles // immutableDataFiles;
  };
  home.file.".local/bin" = {
    source = ../../.local/bin;
    recursive = true;
    executable = true;
  };
}
