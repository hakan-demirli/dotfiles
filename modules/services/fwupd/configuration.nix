_: {
  flake.modules.nixos.services-fwupd = _: {
    services.fwupd.enable = true;
  };
}
