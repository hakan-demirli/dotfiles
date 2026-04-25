{
  flake.modules.nixos.services-fprintd = _: {
    services.fprintd.enable = true;

    security.pam.services = {
      sudo.fprintAuth = true;
      hyprlock.fprintAuth = true;
      sddm.fprintAuth = true;
    };
  };
}
