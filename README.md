|   |   |
|---|---|
| **Distro**      | NixOS        |
| **WM**          | Hyprland     |
| **Bar**         | Waybar       |
| **Editor**      | Helix + Tmux |
| **FileManager** | yazi         |
| **WP-Manager**  | swww         |
| **Keyboard**    | [tbk_mini](https://github.com/Bastardkb/TBK-Mini)-[QMK](./modules/home/config/qmk) |

<!--toc:start-->
- [Build](#build)
- [Installation and Deployment](#installation-and-deployment)
  - [Switch to a new config](#switch-to-a-new-config)
  - [Build without switch](#build-without-switch)
  - [Build an iso or qcow2](#build-an-iso-or-qcow2)
  - [Using minimal ISO](#using-minimal-iso)
  - [Oracle VPS ARM (kexec)](#oracle-vps-arm-kexec)
  - [Oracle VPS x86 (1GB RAM)](#oracle-vps-x86-1gb-ram)
  - [ARM QEMU VM using nixos-anywhere](#arm-qemu-vm-using-nixos-anywhere)
- [Tailscale/Headscale](#tailscaleheadscale)
- [Deploy Secrets](#deploy-secrets)
- [Home-manager](#home-manager)
- [Inventory artifacts](#inventory-artifacts)
<!--toc:end-->

# Build

* ```nix flake check```
* ```nix build .#nixosConfigurations.laptop-0.config.system.build.toplevel```
* ```nix run .#test-codegen-smoke```

# Installation and Deployment
## Switch to a new config
* ```sudo nixos-rebuild switch --flake ./.#laptop-0```

## Build without switch
* ```sudo nixos-rebuild build --flake ~/Desktop/infra/dotfiles/#laptop-0```

## Build an iso or qcow2
* ```nix run github:nix-community/nixos-generators -- --flake .#vps-oracle-0 --format iso```

## Using minimal ISO
  * Boot a nixos ISO.
    * ```sudo cp ./nixos-minimal-*.iso /dev/sdb```
  * Become a root user:
    * ```sudo su```
  * Go to home:
    * ```cd```
  * Get the repo:
      * ```git clone https://github.com/hakan-demirli/dotfiles```
  * Ensure the disk label is correct and matches with the disko config
    * ```lsblk```
  * Format the disk using disko:
    * ```nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake ./dotfiles/#laptop-0```
  * Install nixos:
    * ```nixos-install --root /mnt --flake ./dotfiles/#laptop-0```
  * Reboot
    * ```reboot```

## Oracle VPS ARM (kexec)
* ```nix build .#kexec --system aarch64-linux```
* ```scp -i ~/.ssh/id_ed25519_proton ./result ubuntu@<IP>:/tmp/kexec```
* ```ssh ubuntu@<IP> -i ~/.ssh/id_ed25519_proton -t sudo /tmp/kexec```
* Wait for it to load kexec.
* ```ssh root@<IP> -i ~/.ssh/id_ed25519_proton```
* Continue as if you have booted the minimal iso.

## Oracle VPS x86 (1GB RAM)
* Follow `Oracle VPS ARM` (drop `--system aarch64-linux`) and boot the kexec.
* Compile locally and push:
    * Disko:
        * ```nix build github:nix-community/disko#disko --extra-experimental-features "nix-command flakes" --print-out-paths > /tmp/disko-path.txt```
        * ```DISKO_LOCAL_STORE_PATH=$(cat /tmp/disko-path.txt)```
    * System:
        * ```nix build .#nixosConfigurations.vps-oracle-1.config.system.build.toplevel --extra-experimental-features "nix-command flakes" --print-out-paths > /tmp/system-path.txt```
        * ```SYSTEM_LOCAL_STORE_PATH=$(cat /tmp/system-path.txt)```
    * Copy to VPS:
        * ```nix copy --to ssh://root@<IP>?ssh-key=/home/emre/.ssh/id_ed25519_proton $DISKO_LOCAL_STORE_PATH```
        * ```nix copy --to ssh://root@<IP>?ssh-key=/home/emre/.ssh/id_ed25519_proton $SYSTEM_LOCAL_STORE_PATH```
    * Format the disk:
        * ```REMOTE_DISKO_BIN=$(echo $DISKO_LOCAL_STORE_PATH | sed 's|^/nix/store/||')```
        * ```ssh root@<IP> -i ~/.ssh/id_ed25519_proton "/nix/store/$REMOTE_DISKO_BIN/bin/disko --mode disko /tmp/disko.nix --arg device '\"/dev/sda\"'"```
    * Activate:
        * ```REMOTE_SYSTEM=$(echo $SYSTEM_LOCAL_STORE_PATH | sed 's|^/nix/store/||')```
        * ```bash
          ssh root@<IP> -i ~/.ssh/id_ed25519_proton <<EOF
          mkdir -p /mnt/nix/var/nix/profiles/
          nix-env --profile /mnt/nix/var/nix/profiles/system --set /nix/store/$REMOTE_SYSTEM
          NIXOS_INSTALL_BOOTLOADER=1 /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration boot
          EOF
          ```
        * reboot

## ARM QEMU VM using nixos-anywhere
* Boot minimal iso in qemu and allow ssh access.
* ```nix-shell -p nixos-anywhere```
* ```nixos-anywhere --flake .#vps-oracle-0 root@192.168.1.128```

# Tailscale/Headscale

Headscale runs on `vps-oracle-0` at `https://sshr.polarbearvuzi.com`. Every host auto-registers with `--advertise-tags=tag:bootstrap` on first boot via the sops-managed `tailscale-key`. Promote on the headscale server once verified.

* On a clean install of the headscale server:
  * ```sudo headscale users list```
  * ```sudo headscale users create emre```
  * ```sudo headscale preauthkeys create --user 1 --reusable --expiration 17520h --tags tag:bootstrap```
    * Paste the resulting key into `secrets/secrets.yaml` under `tailscale-key`.
  * git pull and switch on all hosts.
* Promote a fresh node:
  * ```sudo headscale nodes tag -i <id> -t tag:cluster-personal-compute```
* Exit nodes:
  * ```sudo headscale nodes routes list```
  * ```sudo headscale nodes approve-routes -i <id> -r "0.0.0.0/0,::/0"```
  * ```sudo headscale nodes tag -i <id> -t tag:exitnode```
* QOL:
  * ```sudo headscale nodes delete --identifier <id>```
  * ```sudo headscale nodes rename laptop-0 -i <id>```

# Deploy Secrets

The host's age identity = shared bootstrap key in `secrets/age-bootstrap.key.enc` (passphrase-encrypted). Per-host age via ssh-to-age is optional and not required for first boot.

## Fleet bring-up (one-time)
* ```bash secrets/gen-bootstrap-key.sh```
* ```nix build .#sops-yaml && cp -f result secrets/.sops.yaml```

## Setup (one-time per machine)
1. **Decrypt the age key**:
   * ```AGE_KEY="$(age -d secrets/age-bootstrap.key.enc)" || { echo "decrypt failed"; }```
2. **Deploy the key**:
   * ```sudo mkdir -p /mnt/persist/system/var/lib/sops-nix```
   * ```echo "$AGE_KEY" | sudo tee /mnt/persist/system/var/lib/sops-nix/key.txt > /dev/null```
   * ```sudo chmod 600 /mnt/persist/system/var/lib/sops-nix/key.txt```
3. **Install/Switch**:
   * ```sudo nixos-rebuild switch --flake .#hostname```

## Shared servers (no sops by default)
   * Set `[labels].tailscale_auth_key = "false"` in `inventory/hosts/.../<id>.toml`.
   * ```sudo nixos-rebuild switch --flake .#<id>```
   * ```sudo tailscale up --login-server=https://sshr.polarbearvuzi.com --advertise-tags=tag:shared-server```

## Editing Secrets
* ```export SOPS_AGE_KEY="$(age -d secrets/age-bootstrap.key.enc)" || exit 1```
* ```sops --config secrets/.sops.yaml secrets/secrets.yaml```

## Migration from dotfiles
* ```bash secrets/migrate-from-dotfiles.sh```

# Home-manager

Standalone (not wired into nixos hosts). Pick the entry matching the host:

* ```home-manager switch --flake .#emre```           — desktop, no nvidia
* ```home-manager switch --flake .#emre-nvidia```    — desktop with nvidia (laptop-0)
* ```home-manager switch --flake .#emre-headless```  — servers / alien distros

# Inventory artifacts

* ```nix build .#sops-yaml```         — `secrets/.sops.yaml`
* ```nix build .#headscale-acl```     — ACL hujson
* ```nix build .#matchbox```          — matchbox profiles
* ```nix build .#kea```               — Kea DHCP reservations
* ```nix build .#kexec```             — kexec bootstrap bundle
* ```nix run   .#inventory-dump```    — pretty-print resolved inventory
* ```nix run   .#intent-report```     — drift between inventory + nixos config
* ```nix build .#diagrams```          — topology PNGs
