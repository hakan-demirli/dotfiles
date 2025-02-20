{ pkgs }:
{
  services = {
    displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        kdePackages.qtmultimedia
        kdePackages.qtsvg
        kdePackages.qtvirtualkeyboard
      ];
      # https://github.com/NixOS/nixpkgs/issues/355912#issuecomment-2480923686
      settings = {
        General = {
          DefaultSession = "hyprland.desktop";
        };
      };
    };
  };
}
