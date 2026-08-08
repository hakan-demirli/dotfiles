<img width="1921" height="1081" alt="Image" src="https://github.com/user-attachments/assets/3922fbba-ec02-4a65-9da7-54690810e899" />

|          |                                                         |
| -------- | ------------------------------------------------------- |
| Distro   | NixOS                                                   |
| Desktop  | Hyprland + Waybar                                       |
| Editor   | Helix + Tmux                                            |
| Files    | Yazi                                                    |
| Keyboard | [TBK Mini](https://github.com/Bastardkb/TBK-Mini) + QMK |

## Layout

| Path                               | Purpose                                                      |
| ---------------------------------- | ------------------------------------------------------------ |
| `inventory/`                       | Users, access tiers, roles, hosts, clusters, and alert facts |
| `modules/hosts/`                   | Host-specific NixOS modules                                  |
| `modules/{roles,services,system}/` | Reusable NixOS behavior                                      |
| `modules/home/`                    | Rootless, standalone Home Manager tree                       |
| `modules/devices/`                 | Self-contained non-NixOS device builds                       |
| `modules/nix/`                     | Flake outputs, checks, installers, and codegen               |
| `secrets/`                         | SOPS-encrypted data and age identity envelopes               |

Inventory entries are Nix modules. `_defaults.nix` is merged into every entity
in its directory. To add an entity, copy the closest entry, change its `id` and
facts, reference it from the relevant cluster/host, then run `nix flake check`.
Role module references resolve through this repo first and then `infra-lib`.
missing references fail evaluation.

## Develop And Inspect

```bash
nix develop
nix flake check
nix build .#nixosConfigurations.laptop-1.config.system.build.toplevel
nix run .#inventory-dump
nix build .#intent-report
nix build .#diagrams
```

Generated outputs include `sops-yaml`, `headscale-acl`, `matchbox`, `kea`, and
`kexec`. Build one with `nix build .#<name>`. Generated SOPS policy is applied
with `cp -f result secrets/.sops.yaml`, followed by `sops updatekeys` for each
affected encrypted file.

## NixOS

```bash
sudo nixos-rebuild switch --flake .#laptop-1
nix build .#nixosConfigurations.laptop-1.config.system.build.toplevel
```

### Fresh Install

1. Boot a NixOS ISO, clone this repository, and verify the target disk with
   `lsblk` against `inventory/hosts/<zone>/<host>.nix`.
2. Partition it: `nix run github:nix-community/disko -- --mode disko --flake .#<host>`.
3. Install the mandatory password identity, optionally including Tailscale:
   `nix run .#bootstrap-deploy -- /mnt [--with-tailscale]`.
4. Install: `nixos-install --root /mnt --flake .#<host> --no-root-passwd`.
5. Reboot only after bootstrap deployment and installation both succeed.

Managed Disko hosts also expose `nix run .#install-<host>`, which validates the
inventory disk and requires typing `WIPE <host>` before destructive work.

For takeover from a foreign ARM Linux host, build
`nix build .#kexec --system aarch64-linux`, copy `result` to the host, run it as
root, then follow the fresh install flow.

## Home Manager

Profiles are `user-0@desktop`, `user-0@desktop-nvidia`, and `user-0@headless`:

```bash
home-manager switch --flake '.#user-0@desktop'
nix run path:.#deploy-home-secrets
```

Home Manager is rootless and independent from NixOS. `homeStorage` currently
uses a temporary home by default while persisting the paths declared in
`modules/home/users/user-0/default.nix`. On first NixOS enablement, switch NixOS,
switch Home Manager, verify `~/.storage/control/current`, then reboot.

For a Linux target without Nix:

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
| Laptop Wi-Fi      | `secrets/wifi/credentials.yaml`                  | external backup                              | `~/.config/sops/age/wifi.key`                              |

Deploy Home Manager and NixOS secrets separately, as the target user:

```bash
nix run path:.#deploy-home-secrets
nix run path:.#deploy-system-secrets
```

Edit an envelope-backed file without writing its identity to disk:

```bash
export SOPS_AGE_KEY="$(age --decrypt secrets/system.age.key.enc)" || exit 1
sops --config secrets/.sops.yaml secrets/system.yaml
unset SOPS_AGE_KEY
```

Use the matching bootstrap envelope/config for bootstrap files. Wi-Fi and Home
Manager files use `SOPS_AGE_KEY_FILE` with their installed keys and local
`.sops.yaml`.

## Tailnet

Headscale runs on `vps-oracle-0` at `https://sshr.polarbearvuzi.com`. For a new
server, create user `user-0`, create a reusable preauth key tagged
`tag:bootstrap`, store it in `secrets/bootstrap/tailscale.yaml`, and redeploy.
Promote a verified node with `sudo headscale nodes tag -i <id> -t <tag>`.
Approve exit routes with `headscale nodes approve-routes` before assigning
`tag:exitnode`.

`laptop-1` exposes a write-only rsync inbox on `tailscale0` to approved senders:

```bash
nix profile install path:.#send-to-laptop
send-to-laptop FILE...
```

## Non-NixOS Devices

Directories containing `modules/devices/<id>/default.nix` are auto-discovered.
Their `packages` become `<id>-<name>` flake packages. Deployment overlay APIs
are exposed under `devices.<id>.lib`. Keep devices self-contained.

| Device                  | Build                                                    | Deployment                                                   |
| ----------------------- | -------------------------------------------------------- | ------------------------------------------------------------ |
| GL.iNet `router-0`      | `nix build --option sandbox relaxed .#router-0-firmware` | Flash the sysupgrade image and push config overlays over SSH |
| Sipeed `kvm-desk-0`     | `nix build .#kvm-desk-0-config-overlay-empty`            | Flash vendor firmware manually and push overlays over SSH    |
| Pebble `pebble-round-2` | `nix build .#pebble-round-2-firmware`                    | Sideload `result/firmware.pbz` through the mobile app        |

Router and KVM overlay arguments are defined in each device's
`nix/config-overlay.nix`. The router's empty overlay enables the public
`bootstrap`/`bootstrap` AP. Replace it promptly.
