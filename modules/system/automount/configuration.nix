{
  flake.modules.nixos.system-automount = _: {
    services = {
      devmon.enable = true;
      gvfs.enable = true;
      udisks2.enable = true;
    };
  };
}
