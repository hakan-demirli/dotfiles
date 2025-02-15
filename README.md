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
* Enable flakes and commands:
  * ```cp ~/Desktop/dotfiles/.config/nix/nix.conf ~/.config/nix/nix.conf```
* If you have the key decrypt git_tokens and symlink it:
  * read -sp "Enter passphrase: " password && echo && (head -c8 .config/git/git-crypt-key | grep -q '^Salted__' || { echo "File does not appear encrypted."; exit 1; }) && (openssl enc -d -aes-256-cbc -pbkdf2 -in .config/git/git-crypt-key -out /tmp/git-crypt-key -pass pass:"$password" && echo "Decryption complete.") && unset password
  * ```git-crypt unlock ~/git-crypt-key && ln -s ~/.config/mylib/git_tokens ~/.config/git/git_tokens```
* ```sudo nixos-rebuild switch --flake ~/Desktop/dotfiles/#emre```
* ```home-manager switch --flake ~/Desktop/dotfiles/#emre```



/home/emre/Desktop/dotfiles/.config/mylib/git-crypt-key
