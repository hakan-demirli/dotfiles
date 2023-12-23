# Dotfiles

![de](assets/de.png)

|   |   |
|---|---|
| **Distro**      | Arch btw   |
| **WM**          | Hyprland   |
| **Bar**         | Waybar     |
| **Editor**      | Helix+tmux |
| **FileManager** | LF         |
| **WP-Manager**  | swww       |

# Install
* Don't. Paths are hardcoded to my PC. I suggest just using my ./configs.
* Use archinstall on live Arch Linux ISO.
  * Use `iwctl` to connect WIFI if needed.
  * Set followings:
    * Netowork manager
    * pipewire
    * git
    * Username and password
  * ```./scripts/lin/ib.sh i_nix```
  * ```cp ~/dotfiles/.config/nix ~/.config/nix`
  * ```reboot```
  * ```nix run home-manager/master -- switch --flake ~/.config/home-manager#emre -v```
    * Change the user name accordingly
* Auto install my [firefoxCSS](https://github.com/hakan-demirli/Firefox_Custom_CSS).
  * `python ./scripts/python/unused/installFirefoxCSS.py`


# TODO
- Firefox custom file picker: lf/yazi
  - Using xdg-desktop-portal
- trash-cli that works on both windows and linux
  - trash-cli: [buggy?](https://github.com/andreafrancia/trash-cli/issues/65)
- lf delete/trash multiple selections

