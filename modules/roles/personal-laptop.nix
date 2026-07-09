{ pkgs, ... }:
{
  services = {
    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    yubikey.pamOrigin = "pam://emre-sudo";

    displayManager.sddm.theme = "sddm-astronaut-theme";
  };

  users.users.emre.linger = true;

  environment.systemPackages = [
    (pkgs.callPackage ../pkgs/sddm-astronaut.nix { })
  ];

  fonts.packages = [
    (pkgs.callPackage ../pkgs/ms-fonts.nix { })
  ];
}
