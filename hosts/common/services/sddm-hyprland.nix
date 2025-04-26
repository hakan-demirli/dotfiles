{
  lib,
  pkgs,
  ...
}:
{
  programs.hyprland = {
    enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";

    wayland.enable = true;

    extraPackages = with pkgs; [
      kdePackages.qtwayland
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qtvirtualkeyboard
    ];
    settings = {
      General = {
        DefaultSession = "hyprland.desktop";
      };
      Wayland = {
        CompositorCommand = "${lib.getExe pkgs.weston} --backend=drm-backend.so --shell=kiosk-shell.so";
      };
    };
  };

  services = {
    xserver.enable = true;
    xserver.excludePackages = [ pkgs.xterm ];
    gnome.gnome-keyring.enable = true;
  };

  imports = [ ../system/polkit-agent.nix ];
  environment.systemPackages = [
    (pkgs.callPackage ../../../pkgs/sddm-astronaut.nix {
      # theme = "pixel_sakura";
    })
  ];
}
