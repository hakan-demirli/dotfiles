# modules/home/

Self-contained home-manager tree. Deployable to any Linux box with
`home-manager` installed. Does not require NixOS or root.

## Contract

- `rm -rf modules/home/` -- system still builds. Home and system are
  independent.
- Copy this directory to another repo, add a `flake.nix` (see below),
  and it deploys unchanged.
- Only coupling to the rest of dotfiles is via `flake.nix` inputs at
  the root -- single lock file when embedded.
- The username inside `users/<id>/default.nix` matching a NixOS system
  account is coincidence, not a coupling. Nothing here reads system
  inventory.

## Layout

```
modules/home/
  common/
    default.nix          <- base packages + shell
    config/              <- static dotfiles
    pkgs/                <- overlays + user services
    profiles/
      desktop.nix
      headless.nix
    modules/
      sops.nix           <- home-manager sops wrapper (relative paths)
  users/
    <identity>/
      default.nix        <- home.username, homeDirectory, homeSops.identity
      secrets.yaml       <- sops-encrypted user secrets
      .sops.yaml         <- per-user creation_rules
```

## Deploy (embedded in dotfiles)

1. Place your age key at `~/.config/sops/age/keys.txt` (mode 0600).
2. Run:
   * ```home-manager switch --flake .#"user-0@desktop-nvidia"```

Variants: `user-0@desktop`, `user-0@headless`.

## Deploy (standalone, e.g. Ubuntu VM)

1. Copy this directory to a new git repo.
2. Add a `flake.nix` at the root declaring `nixpkgs`, `home-manager`,
   `sops-nix` inputs.
3. Add a `homeConfigurations` output mirroring
   `modules/nix/home.nix` in dotfiles.
4. Place your age key at `~/.config/sops/age/keys.txt` (mode 0600).
5. Run:
   * ```home-manager switch --flake .#"user-0@desktop"```

## Age key deployment

The user is responsible for placing `~/.config/sops/age/keys.txt`.
Home never asks the system to provide it. Options:

- Copy from a password manager / YubiKey / other trusted store.
- Decrypt from a passphrase-protected blob you carry between machines.
- On NixOS boxes managed by dotfiles, opt-in to a system-side bridge
  module (not yet implemented) that drops the plaintext keyfile from
  an encrypted blob in `secrets/system.yaml`.

## Add a new identity

1. `cp -r users/user-0 users/user-1` -- edit `default.nix`
   (`home.username`, `homeDirectory`, `homeSops.identity`).
2. Edit `users/user-1/.sops.yaml` -- replace the age recipient with
   user-1's age public key.
3. Overwrite `users/user-1/secrets.yaml` with user-1's plaintext
   secrets and `sops encrypt --in-place` it.
4. Add a new entry to `modules/nix/home.nix` (in the embedding flake).
