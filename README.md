# Dotfiles

![de](assets/de.png)

|   |   |
|---|---|
| **Distro**      | Nixos      |
| **WM**          | Hyprland   |
| **Bar**         | Waybar     |
| **Editor**      | Helix+tmux |
| **FileManager** | LF         |
| **WP-Manager**  | swww       |

# Install
* Decrypt secrets
  * ```git-crypt unlock ../git-crypt-key```
* ```sudo nixos-rebuild switch --flake ~/dotfiles/#myNixos```
* ```home-manager switch --flake ~/dotfiles/#emre```

# TODO
- nix: btop GPU
- nix: missing tray icons
- py: fix hardcoded paths
- Firefox custom file picker: lf/yazi
  - Using xdg-desktop-portal ?
