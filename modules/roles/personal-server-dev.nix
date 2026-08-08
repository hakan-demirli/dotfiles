{ lib, ... }:
{
  services = {
    sops.bootstrap.passwordAccount = "root";

    openssh.settings.PermitRootLogin = lib.mkForce "no";

    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    slurm-cluster.enable = true;
  };

  networking.networkmanager.enable = true;
  programs.nix-ld.enable = true;

  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults:%wheel rootpw
    '';
  };

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

}
