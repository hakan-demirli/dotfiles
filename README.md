# Dotfiles

![de](doc/assets/de.png)

|   |   |
|---|---|
| **Distro**      | NixOS        |
| **WM**          | Hyprland     |
| **Bar**         | Waybar       |
| **Editor**      | Helix + Tmux |
| **FileManager** | yazi         |
| **WP-Manager**  | swww         |
| **Keyboard**    | [tbk_mini](https://github.com/Bastardkb/TBK-Mini)-[QMK](https://github.com/hakan-demirli/dotfiles/tree/main/.local/share/qmk) |

```
.
├── doc
│   ├── assets: Static files like images for documentation.
│   └── notes: Markdown notes.
├── hosts
│   ├── laptop: Laptop configuration (system and hardware settings).
│   └── vm: Virtual machine configuration (system and hardware settings).
├── pkgs
│   ├── derivations: Nix derivations for srcs.
│   └── src: Source code for derivations.
├── secrets: Tokens and certificates.
├── overlay.nix: Custom Nix package overlays.
└── users
    └── emre: User-specific configurations.
```

# Install
* ```mkdir -p ~/Desktop && cd ~/Desktop```
* ```git clone https://github.com/hakan-demirli/dotfiles```
* ```nix-shell -p git git-crypt home-manager helix```
* Enable flakes and commands:
  * ```mkdir -p ~/.config/nix```
  * ```cp ~/Desktop/dotfiles/.config/nix/nix.conf ~/.config/nix/nix.conf```
* If you have the key decrypt git_tokens and symlink it:
  * ```nix-shell -p openssl```
  * ```read -sp "Enter passphrase: " password && echo && (head -c8 ~/Desktop/dotfiles/secrets/git-crypt-key | grep -q '^Salted__' || { echo "File does not appear encrypted."; exit 1; }) && (openssl enc -d -aes-256-cbc -pbkdf2 -in ~/Desktop/dotfiles/secrets/git-crypt-key -out /tmp/git-crypt-key -pass pass:"$password" && echo "Decryption complete.") && unset password```
  * ```git-crypt unlock /tmp/git-crypt-key && ln -s ~/Desktop/dotfiles/secrets/git_tokens ~/.config/git/git_tokens && ln -s ~/Desktop/dotfiles/secrets/git_users ~/.config/git/git_users```
* ```sudo nixos-rebuild switch --flake ~/Desktop/dotfiles/#emre```
* ```home-manager switch --flake ~/Desktop/dotfiles/#emre```
