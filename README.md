# Dotfiles

![de](doc/assets/de.png)

|   |   |
|---|---|
| **Distro**      | NixOS        |
| **WM**          | Hyprland     |
| **Bar**         | Waybar       |
| **Editor**      | Helix + Tmux |
| **FileManager** | lf           |
| **WP-Manager**  | swww         |
| **Keyboard**    | [tbk_mini](https://github.com/Bastardkb/TBK-Mini)-[QMK](https://github.com/hakan-demirli/dotfiles/tree/main/.local/share/qmk) |

```
.
├── doc
│   ├── assets: Stores static files like images for documentation.
│   └── notes: Contains markdown notes.
├── profiles
│   └── personal: Contains personal nix profile.
└── system
    ├── app: Contains nix applications and patches.
    ├── hardware: Contains hardware-specific nix configurations.
    └── scripts: Contains various scripts.
  
```

# Install
* ```nix-shell -p git git-crypt home-manager helix```
* If you don't have the key remove/rename git config.
  * ```mv ./.config/git/config ./.config/git/config_bckp```
* If you have the key decrypt secrets
  * ```git-crypt unlock ../git-crypt-key```
* ```sudo nixos-rebuild switch --flake ~/Desktop/dotfiles/#myNixos```
* ```home-manager switch --flake ~/Desktop/dotfiles/#emre```
