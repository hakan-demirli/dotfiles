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
│   ├── deployment.md: Installation and deployment guide.
│   └── notes: Markdown notes.
├── hosts
│   └── xxxx: Host-specific configurationrs (system and hardware settings).
├── pkgs: Nix derivations for srcs.
├── secrets: Tokens and certificates.
├── overlay.nix: Custom Nix package overlays.
└── users
    └── xxxx: User-specific configurations.
```

# Installation and Deployment

## Using minimal ISO
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
    * ```sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./dotfiles/hosts/common/hardware/disko-btrfs-lvm.nix --arg diskDevice '"/dev/vda"'```
  * Obtain a new hardware-configuration.nix for your device
    * Generate nixos config:
      * ```sudo nixos-generate-config --no-filesystems --root .```
  * Create a new host dir for your device and copy hardware-configurations.nix there: 
    * ```cp ./etc/nixos/hardware-configuration.nix ./dotfiles/hosts/vm/hardware```
  * Install nixos:
    * ```nixos-install --root /mnt --flake ./dotfiles/.#vm```
  * Reboot
    * ```reboot```

## Oracle VPS ARM
* Set authorizedKeys in ./kexec.nix
* ```nix-build --system aarch64-linux '<nixpkgs/nixos>' -A config.system.build.kexec_bundle -I nixos-config=./kexec.nix```
* ```scp -i ~/.ssh/id_ed25519_proton ./result ubuntu@140.238.223.249:/tmp/kexec```
* ```ssh ubuntu@140.238.223.249 -i ~/.ssh/id_ed25519_proton -t sudo /tmp/kexec```
* Wait for it to load kexec.
* ```ssh root@140.238.223.249 -i ~/.ssh/id_ed25519_proton```
* Continue as if you have booted the minimal iso

## Oracle VPS x86 (1GB RAM)
* Follow `Oracle VPS ARM` installation guide (remove `--system aarch64-linux` from nix-build) and boot the kexec image.
* Compile everything local and send it to vm:
    * Prepare disko:
        * ```nix build --extra-experimental-features "nix-command flakes" github:nix-community/disko#disko --print-out-paths > /tmp/disko-path.txt```
        * ```DISKO_LOCAL_STORE_PATH=$(cat /tmp/disko-path.txt)```
        * ```echo "Disko built locally at: $DISKO_LOCAL_STORE_PATH"```
    * Prepare the system:
        * ```nix build .#nixosConfigurations.vm_oracle_x86.config.system.build.toplevel --extra-experimental-features "nix-command flakes"  --print-out-paths > /tmp/system-path.txt```
        * ```SYSTEM_LOCAL_STORE_PATH=$(cat /tmp/system-path.txt)```
        * ```echo "System built locally at: $SYSTEM_LOCAL_STORE_PATH"```
    * Copy the system and disko to VPS:
        * ```nix copy --to ssh://root@140.238.223.249?ssh-key=/home/emre/.ssh/id_ed25519_proton $DISKO_LOCAL_STORE_PATH```
        * ```nix copy --to ssh://root@VPS_IP?ssh-key=/home/YOUR_USER/.ssh/id_ed25519_proton $SYSTEM_LOCAL_STORE_PATH```
        * ```scp -i ~/.ssh/id_ed25519_proton /home/emre/Desktop/dotfiles/hosts/vm_oracle/hardware/disko.nix root@140.238.223.249:/tmp/disko.nix```
    * Format the disk using disko:
        * ```REMOTE_DISKO_BIN_PATH=$(echo $DISKO_LOCAL_STORE_PATH | sed 's|^/nix/store/||') # Get the hash-name part```
        * ```REMOTE_DISKO_BIN_PATH="/nix/store/$REMOTE_DISKO_BIN_PATH/bin/disko"```
        * ```ssh root@140.238.223.249 -i ~/.ssh/id_ed25519_proton "$REMOTE_DISKO_BIN_PATH --mode disko /tmp/disko.nix --arg device '\"/dev/sda\"'"```
    * Activate the system:
        * ```REMOTE_SYSTEM_STORE_PATH=$(echo $SYSTEM_LOCAL_STORE_PATH | sed 's|^/nix/store/||') # Get the hash-name part```
        * ```REMOTE_SYSTEM_STORE_PATH="/nix/store/$REMOTE_SYSTEM_STORE_PATH"```
        * 
        ```bash
        ssh root@VPS_IP -i ~/.ssh/id_ed25519_proton <<EOF
        mkdir -p /mnt/nix/var/nix/profiles/

        nix-env --profile /mnt/nix/var/nix/profiles/system --set $REMOTE_SYSTEM_STORE_PATH
        NIXOS_INSTALL_BOOTLOADER=1 /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration boot

        echo "Activation finished."
        EOF
        ```
        * reboot

## ARM QEMU VM using nixos-anywhere
* Boot minimal iso in qemu and allow ssh access
* On your pc: ```nix-shell -p nixos-anywhere```
* ```nixos-anywhere  --flake .#vm_oracle_aarch64 root@192.168.1.128```

# Switch to a new config
*  ```sudo nixos-rebuild switch --flake ./.#laptop```

# Build without switch
* ```sudo nixos-rebuild build --flake ~/Desktop/dotfiles/#laptop```

# Build an iso or qcow2
* ```nix run github:nix-community/nixos-generators -- --flake .#vm_oracle_aarch64 --format iso```

# Deploy Secrets
* Decrypt:
  * ```nix-shell -p openssl```
  * ```read -sp "Enter passphrase: " password && echo && (head -c8 ~/Desktop/dotfiles/secrets/git-crypt-key | grep -q '^Salted__' || { echo "File does not appear encrypted."; exit 1; }) && (openssl enc -d -aes-256-cbc -pbkdf2 -in ~/Desktop/dotfiles/secrets/git-crypt-key -out /tmp/git-crypt-key -pass pass:"$password" && echo "Decryption complete.") && unset password```
* If decrypted, secrets are automatically symlinked/deployed on boot using `pkgs/symlink_secrets.nix`
  * Manual deployment:
    * ```cd ~/Desktop/dotfiles/ && git-crypt unlock /tmp/git-crypt-key && ln -s ~/Desktop/dotfiles/secrets/{git_tokens,git_users,git_keys} ~/.config/git/ && ln -s ~/Desktop/dotfiles/secrets/.ssh ~/.ssh```
  *  IF ENCRYPTED DO NOT DEPLOY
