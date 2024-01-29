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
* ```nix-shell -p git git-crypt home-manager helix```
* If you don't have the key remove/rename git config.
  * ```mv ./.config/git/config ./.config/git/config_bckp```
* If you have the key decrypt secrets
  * ```git-crypt unlock ../git-crypt-key```
* ```sudo nixos-rebuild switch --flake ~/dotfiles/#myNixos```
* ```home-manager switch --flake ~/dotfiles/#emre```

# TODO
- nix: btop GPU
- py: fix hardcoded paths
- Firefox custom file picker: lf/yazi
  - Using xdg-desktop-portal ?
