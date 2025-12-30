{
  flake.modules.nixos.system-gnupg = { ... }: {
    programs.gnupg.agent = {
      enable = true;
    };
  };
}
