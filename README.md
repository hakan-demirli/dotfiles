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
* Use your hardware-configuration.nix
* Remove nvidia.nix if it is not required
* Change user name
* Decrypt secrets
  * ```git-crypt unlock ../git-crypt-key```
* ```sudo nixos-rebuild switch --flake ~/dotfiles/#myNixos```

# TODO
- nix: fix home-manager
- nix: btop GPU
- nix: missing tray icons
- py: fix hardcoded paths
- Firefox custom file picker: lf/yazi
  - Using xdg-desktop-portal ?
