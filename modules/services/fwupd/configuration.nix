{
  inputs,
  ...
}:
{
  flake.modules.nixos.services-fwupd = { ... }: {
    services.fwupd.enable = true;
  };
}
