{
  flake.modules.nixos.system-gnupg = _: {
    programs.gnupg.agent = {
      enable = true;
      enableExtraSocket = true;
    };
  };
}
