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
- [Repo layout](#repo-layout)
- [Build](#build)
- [Installation and Deployment](#installation-and-deployment)
- [Tailscale/Headscale](#tailscaleheadscale)
- [Deploy Secrets](#deploy-secrets)
- [Home-manager](#home-manager)
- [Inventory artifacts](#inventory-artifacts)
<!--toc:end-->

# Repo layout

This flake covers two independent surfaces:

| Surface       | Scope         | Auth needed | Entry point                        |
|---------------|---------------|-------------|------------------------------------|
| **System**    | `/`, kernel, services, users, boot | root/sudo | `nixosConfigurations.<host>` (`nixos-rebuild switch`) |
| **Home**      | `$HOME`, dotfiles, user services   | user       | `homeConfigurations."emre-*"` (`home-manager switch`) |

They are kept fully separate on purpose:

- The **system side** is driven by `inventory/` (Nix facts) + `modules/` (role
  and host closures). One host = one `nixos-rebuild`. It needs sudo, wipes and
  re-creates activation atomically, and is expected to run on NixOS boxes.
- The **home side** is standalone: `home-manager switch --flake .#emre-<variant>`
  runs as the user, edits `$HOME` only, and works on NixOS *or* any other
  distro (linux) where you already have `home-manager` installed. It never
  touches system paths and does not require sudo.

Currently modeled hosts (aggressive intro-one-by-one philosophy — reintroduce
the rest as they come back online):

- `laptop-0`  — daily-driver laptop
- `vps-oracle-0` — ARM VPS: headscale + slurm master + observability

# Build

* ```nix flake check```
* ```nix build .#nixosConfigurations.laptop-0.config.system.build.toplevel```
* ```nix run .#test-codegen-smoke```

# Installation and Deployment

## Switch to a new system config

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

## Editing Secrets

* ```export SOPS_AGE_KEY="$(age -d secrets/age-bootstrap.key.enc)" || exit 1```
* ```sops --config secrets/.sops.yaml secrets/secrets.yaml```

# Home-manager

`$HOME`-only, no sudo. Pick the entry matching your host:

* ```home-manager switch --flake .#emre```           — generic desktop, no nvidia
* ```home-manager switch --flake .#emre-nvidia```    — desktop with nvidia (laptop-0)
* ```home-manager switch --flake .#emre-headless```  — servers / alien distros

These are decoupled from `nixosConfigurations` on purpose: the same
home closure works on a bare Ubuntu box or inside a container, so long as
`home-manager` is on `PATH`.

# Inventory artifacts

* ```nix build .#sops-yaml```         — `secrets/.sops.yaml`
* ```nix build .#headscale-acl```     — ACL hujson
* ```nix build .#matchbox```          — matchbox profiles
* ```nix build .#kea```               — Kea DHCP reservations
* ```nix build .#kexec```             — kexec bootstrap bundle
* ```nix run   .#inventory-dump```    — pretty-print resolved inventory
* ```nix run   .#intent-report```     — drift between inventory + nixos config
* ```nix build .#diagrams```          — topology SVGs
