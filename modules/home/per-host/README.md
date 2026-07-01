# per-host overrides

`flake.nix` auto-imports `home/per-host/<hostId>.nix` when the file
exists. The file is a plain home-manager module layered on top of
`default.nix` + the chosen profile (`desktop.nix` / `headless.nix`) and
applied last, so it can override anything those set.

## Naming

Filename must match the inventory host `id` exactly (the same string
that appears as `emre@<id>` in `nix flake show`). Look at the
inventory:

```bash
nix eval --json \
  /home/emre/Desktop/infra/infra-personal#lib.inventory.hosts \
  --apply 'h: builtins.attrNames h'
```

Examples: `laptop-0.nix`, `server-fpga-build-0.nix`, `vps-oracle-1.nix`.

## Signature

```nix
{ pkgs, lib, config, facts, ... }:
{
  # ...arbitrary home-manager options...
}
```

`facts` is the per-host fact record from `infra-personal.lib.hostFacts`
(`{ id; system; os; roles; cluster; mainboard; location; labels; }`),
same as in the shared profile modules. `inputs` is also available via
`extraSpecialArgs` if you need to reach into nixpkgs / nur / etc.

## Example

```nix
# home/per-host/laptop-0.nix
{ pkgs, lib, facts, ... }:
{
  # Higher-DPI screen: bump terminal font.
  programs.alacritty.settings.font.size = lib.mkForce 13.0;

  # Extra host-specific topic on the ntfy listener.
  home.sessionVariables.NTFY_EXTRA_TOPIC = "emre-laptop-0";
}
```

## Verify it loads

```bash
nix build .#homeConfigurations."emre@<host>".activationPackage
```

If the file has a syntax error or a bad option, that build fails fast
and points at the offending line.

## When NOT to put it here

If a tweak applies to a class of hosts (every laptop, every
`personal-server`), branch on `facts.roles` / `facts.labels` /
`facts.mainboard` inside `home/desktop.nix` or `home/headless.nix`
instead. This directory is for genuine one-offs.
