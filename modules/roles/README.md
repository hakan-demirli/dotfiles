# modules/roles/

Per-role NixOS module implementations.

Each role declared in `inventory/roles/<id>.toml` may have a matching
`modules/roles/<id>.nix` here. `lib/mkRole.nix` looks it up by name; missing
modules are silently skipped so a role can exist as inventory-only.

## Present today

- `personal-laptop.nix` -- tailscale client + slurm-client wiring for
  `laptop-*` hosts (l01/l02 in the dotfiles era).
- `personal-server.nix` -- tailscale client + slurm-client wiring for
  `server-dev-*` general-purpose home servers.
- `cloud-vps-control.nix` -- headscale server + tailscale client +
  reverse-ssh-server + ntfy + docker-registry for the Oracle Cloud
  control-plane VPS (`vps-oracle-0`).

The remaining roles in `inventory/roles/` (e.g. `dev-fpga`,
`lab-fpga-*`, `mgmt-observability`, `kvm-guest`, `external`,
`laptop-darwin`) are inventory-only today and get their behaviour
purely from the modules they reference in their `modules` list.

## How a role's behaviour is assembled

- `modules/common/{role-identity,sshd,auto-upgrade}.nix` (referenced via
  `inventory/roles/<id>.toml#modules`).
- The role's `tunables` block (free-form data the closure reads).
- Optionally, the sister file in this directory (this README's list).

To add a new role implementation: write `modules/roles/<id>.nix`, then
reference it in `inventory/roles/<id>.toml#modules` as `roles/<id>`. The
resolver finds it via:

```
modules/roles/<id>.nix     <- preferred
modules/services/<id>.nix
modules/common/<id>.nix
modules/<id>.nix
```
