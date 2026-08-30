<img width="1921" height="1081" alt="Image" src="https://github.com/user-attachments/assets/3922fbba-ec02-4a65-9da7-54690810e899" />

|          |                                                         |
| -------- | ------------------------------------------------------- |
| Distro   | NixOS                                                   |
| Desktop  | Hyprland + Quickshell                                   |
| Editor   | Helix + Tmux                                            |
| Files    | Yazi                                                    |
| Keyboard | [TBK Mini](https://github.com/Bastardkb/TBK-Mini) + QMK |

## Layout

| Path                                          | Purpose                                                     |
| --------------------------------------------- | ----------------------------------------------------------- |
| `inventory/`                                  | Users, Unix tiers, deployment/topology, hosts, and clusters |
| `modules/hosts/`                              | Host-specific NixOS modules                                 |
| `modules/{deployment-roles,services,system}/` | Reusable NixOS behavior                                     |
| `modules/home/`                               | Rootless, standalone Home Manager tree                      |
| `modules/devices/`                            | Self-contained non-NixOS device builds                      |
| `modules/nix/`                                | Flake outputs, checks, installers, and codegen              |
| `secrets/`                                    | SOPS-encrypted data and age identity envelopes              |

## Develop And Inspect

```bash
nix develop
nix flake check
nix build .#nixosConfigurations.laptop-1.config.system.build.toplevel
nix run .#inventory-dump
nix build .#intent-report
nix build .#diagrams
```

## NixOS

```bash
sudo nixos-rebuild switch --flake .#laptop-1
nix build .#nixosConfigurations.laptop-1.config.system.build.toplevel
```

### Fresh Install

1. Boot a NixOS ISO, clone this repository, and verify the target disk with
   `lsblk` against `inventory/hosts/<owner>/<host>.nix`.
2. Partition it: `nix run github:nix-community/disko -- --mode disko --flake .#<host>`.
3. Install the mandatory password identity, optionally including Tailscale:
   `nix run .#bootstrap-deploy -- /mnt [--with-tailscale]`.
4. Install: `nixos-install --root /mnt --flake .#<host> --no-root-passwd`.
5. Reboot.

#### ARM Bootstrap

`nix build .#kexec --system aarch64-linux`, copy `result` to the host, run it as root, then follow the fresh install flow.

#### Auto Deploy

`nix run .#install-<host>` and type `WIPE <host>`

## Home Manager

```bash
home-manager switch --flake '.#user-0@desktop'
home-manager switch --flake '.#user-0@desktop-nvidia'
home-manager switch --flake '.#user-0@headless'
home-manager switch --flake '.#user-0@vps-oracle-0'
nix run path:.#deploy-home-secrets
```

### Without Nix

```bash
nix build '.#homeConfigurations."user-0@headless".config.home.portablehome'
./result/deploy.sh --dry-run user@host
./result/deploy.sh user@host
```

## Secrets

| Area              | Encrypted data                                   | Identity source                              | Installed key                                              |
| ----------------- | ------------------------------------------------ | -------------------------------------------- | ---------------------------------------------------------- |
| Login bootstrap   | `secrets/bootstrap/password.yaml`                | `secrets/bootstrap/password.age.key.enc`     | `/persist/system/var/lib/sops-nix/bootstrap-password.key`  |
| Tailnet bootstrap | `secrets/bootstrap/tailscale.yaml`               | `secrets/bootstrap/tailscale.age.key.enc`    | `/persist/system/var/lib/sops-nix/bootstrap-tailscale.key` |
| System services   | `secrets/system.yaml`                            | `secrets/system.age.key.enc`                 | `/persist/system/var/lib/sops-nix/key.txt`                 |
| Home Manager      | `modules/home/users/user-0/secrets/secrets.yaml` | `secrets/identities/home-user-0.age.key.enc` | `~/.config/sops/age/keys.txt`                              |
| Laptop Wi-Fi      | `secrets/wifi/credentials.yaml`                  | `secrets/wifi/age.key.enc`                   | `~/.config/sops/age/wifi.key`                              |

Deploy Home Manager and NixOS secrets separately, as the target user:

```bash
nix run path:.#deploy-home-secrets
nix run path:.#deploy-system-secrets
```

## Tailnet

Headscale runs on `vps-oracle-0` at `https://sshr.polarbearvuzi.com`.
Every node initially receives `tag:bootstrap` using preauth key in `secrets/bootstrap/tailscale.yaml`.
Permanent tags are assigned manually without re-registering the node.

- `nix build .#diagrams-tailnet`
- `sudo headscale nodes tag -i <id> -t tag:first,tag:second`.

## Non-NixOS Devices

| Device                  | Build                                         | Deployment                                                           |
| ----------------------- | --------------------------------------------- | -------------------------------------------------------------------- |
| GL.iNet `router-0`      | `nix run .#router-0-firmware`                 | `nix run .#router-0-firmware-flash` then `nix run .#router-0-config` |
| Sipeed `kvm-desk-0`     | `nix build .#kvm-desk-0-config-overlay-empty` | Flash vendor firmware manually and push overlays over SSH            |
| Pebble `pebble-round-2` | `nix build .#pebble-round-2-firmware`         | Sideload `result/firmware.pbz` through the mobile app                |
