# modules/roles/

Per-role NixOS module implementations.

Each role declared in `inventory/roles/<id>.nix` lists Nix modules under
its `modules` array. `lib/mkRole.nix` resolves each ref against a fixed
search path (roles → services → common → top-level, consumer repo first,
then infra-lib). A ref that resolves to no file is a hard error: the eval
throws with the full search path so you see exactly where it looked. No
silent skips.

If you want an inventory role without a matching `modules/roles/<id>.nix`
here, keep the sister file out and let the role's behaviour come purely
from the other modules it lists — but every listed ref must exist somewhere
in the search path.

## Present today

- `personal-laptop.nix` -- tailscale client + slurm-client + yubikey +
  sddm astronaut theme wiring for `laptop-0`.
- `cloud-vps-control.nix` -- headscale server + tailscale client +
  reverse-ssh-server + slurm master + transmission for the Oracle Cloud
  control-plane VPS (`vps-oracle-0`).

`mgmt-observability` is declared in `inventory/roles/` but has no sister
`.nix` here; its behaviour comes entirely from the modules referenced in
its `modules` list (`services/victoriametrics`, `services/grafana`,
`services/vmalert`, `services/alertmanager`) sourced from `infra-lib`.

## How a role's behaviour is assembled

- Modules listed in `inventory/roles/<id>.nix#modules` are resolved via:
  ```
  modules/roles/<id>.nix     <- preferred
  modules/services/<id>.nix
  modules/common/<id>.nix
  modules/<id>.nix
  ```
- The role's `tunables` block (free-form data the closure reads).
- Optionally, the sister file in this directory (list above).

To add a new role implementation: write `modules/roles/<id>.nix`, then
reference it in `inventory/roles/<id>.nix#modules` as `roles/<id>`.
