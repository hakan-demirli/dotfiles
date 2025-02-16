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
## New Device Installation
  * Boot a nixos ISO.
    * ```sudo cp ./nixos-minimal-24.11.714287.a45fa362d887-x86_64-linux.iso /dev/sdb```
  * Become a root user:
    * ```sudo su```
  * Go to home:
    * ```cd```
  * Find out the disk you want to install nixos to:
    * ```lsblk```
  * Create a disko layout, or borrow someone elses layout:
    * Get all layouts in this repo.
      * ```git clone https://github.com/hakan-demirli/dotfiles```
  * Format the disk using disko:
    * ```sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./dotfiles/hosts/vm/hardware/disko.nix --arg device '"/dev/vda"'```
  * Obtain a new hardware-configuration.nix for your device
    * Generate nixos config:
      * ```sudo nixos-generate-config --no-filesystems --root .```
  * Create a new host dir for your device and copy hardware-configurations.nix there: 
    * ```cp ./etc/nixos/hardware-configuration.nix ./dotfiles/hosts/vm/hardware```
  * Install nixos:
    * ```nixos-install --root /mnt --flake ./dotfiles/.#vm```
  * Reboot
    * ```reboot```

# Update
*  ```sudo nixos-rebuild switch --flake ./.#laptop```

# Build without switch
* ```sudo nixos-rebuild build --flake ~/Desktop/dotfiles/#laptop```

# Deploy Secrets
* ```nix-shell -p openssl```
* ```read -sp "Enter passphrase: " password && echo && (head -c8 ~/Desktop/dotfiles/secrets/git-crypt-key | grep -q '^Salted__' || { echo "File does not appear encrypted."; exit 1; }) && (openssl enc -d -aes-256-cbc -pbkdf2 -in ~/Desktop/dotfiles/secrets/git-crypt-key -out /tmp/git-crypt-key -pass pass:"$password" && echo "Decryption complete.") && unset password```
* ```git-crypt unlock /tmp/git-crypt-key && ln -s ~/Desktop/dotfiles/secrets/git_tokens ~/.config/git/git_tokens && ln -s ~/Desktop/dotfiles/secrets/git_users ~/.config/git/git_users```
* ```sudo nixos-rebuild switch --flake ~/Desktop/dotfiles/#laptop```
