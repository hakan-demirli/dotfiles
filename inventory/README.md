# inventory/

Nix facts. Read by mkRole, codegen, diagrams.

Every file is a Nix module. Loader in `infra-lib/modules/lib/inventory.nix` reads
`inventory/<kind>/*.nix` and chains each through `evalModules` with the schema
from `types.nix`. Files whose basename starts with `_` are treated as shared
modules, not entities.

## Dirs
- `users`, `access-tiers`, `roles`, `hosts`, `clusters`
- Optional (auto-synth): `teams`, `projects`

## Defaults + inheritance

Each `<kind>/` may contain a `_defaults.nix` module that is merged into every
entity in that directory before the schema is applied. Standard NixOS module
semantics: scalars use `mkDefault`/`mkForce`, `listOf` fields concatenate.

Example — `inventory/users/_defaults.nix`:
```nix
{ lib, ... }:
{
  kind = lib.mkDefault "human";
  cohort = lib.mkDefault "staff";
  system_account = {
    shell = lib.mkDefault "zsh";
    groups = [ "wheel" "apptainer" "kvm" "libvirtd" "networkmanager" "audio" "video" "input" ];
  };
}
```

A user file inherits everything and only writes deltas:
```nix
{
  id = "user-0";
  cohort = "admin";
  system_account = { username = "emre"; uid = 1000; };
  keys.ssh = [ "ssh-ed25519 AAAA…" ];
}
```

To add to `groups`: `system_account.groups = [ "wireshark" ];` (auto-appended).
To replace `groups` entirely: `system_account.groups = lib.mkForce [ "wheel" ];`.

## Add a user with admin on the personal cluster
1. `cp users/user-0.nix users/user-1.nix`, edit `id`, `system_account`, `keys.ssh`.
2. Append to `clusters/personal.nix` under `access.users`:
   ```nix
   access.users = [
     { user = "user-1"; tier = "admin"; }
   ];
   ```
3. `sudo nixos-rebuild switch --flake .#<host>` on each cluster host.

## Add a tier
1. `cp access-tiers/admin.nix access-tiers/standard.nix`
2. Edit `id`, `sudo`, `ssh.allowed`, `slurm_qos`.
3. Reference `tier = "standard"` from a cluster grant.

## Add a host reusing an existing role
1. `cp hosts/personal/laptop-0.nix hosts/personal/laptop-1.nix`
2. Edit `id`, `hardware`, `disko.root_disk`, `ownership.owner`.
3. `sudo nixos-rebuild switch --flake .#laptop-1`

## Add a host with a new host-local user, both get sudo on it
1. `cp users/user-0.nix users/user-lab.nix`, edit `id`, `uid`, `keys`.
2. `cp hosts/personal/laptop-0.nix hosts/personal/lab-box.nix`, edit `id`, `hardware`, `disko`, `ownership.owner = "user-lab"`.
3. Grant admin on the cluster (see the user-add recipe above).
4. `sudo nixos-rebuild switch --flake .#lab-box`

## Add a cluster with its own slurm controller
1. `cp clusters/personal.nix clusters/lab.nix`
2. Edit `id`, `scheduler.controllers`, `scheduler.partitions`, `members.roles`, `access`.
3. Controller host's role must import `services/slurm` with `isMaster = true` (see `modules/roles/cloud-vps-control.nix`).
4. `sudo nixos-rebuild switch --flake .#<controller>` and each compute host.

## Add a role
1. `cp roles/personal-laptop.nix roles/lab-compute.nix`
2. Edit `id`, `modules`.
3. Optional: `modules/roles/lab-compute.nix` for role-specific NixOS options.
4. Reference by `roles = [ "lab-compute" ]` in a host, then switch.
