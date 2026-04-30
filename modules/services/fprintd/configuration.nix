{
  flake.modules.nixos.services-fprintd =
    { pkgs, ... }:
    {
      services.fprintd.enable = true;

      security.pam.services = {
        sudo.fprintAuth = true;
        hyprlock.fprintAuth = true;
        sddm.fprintAuth = true;
      };

      systemd.services.fprintd-resume = {
        description = "Restart fprintd after resume from suspend";
        before = [ "sleep.target" ];
        wantedBy = [ "sleep.target" ];
        unitConfig = {
          DefaultDependencies = "no";
          StopWhenUnneeded = true;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "/run/current-system/sw/bin/true";
          ExecStop = "${pkgs.systemd}/bin/systemctl restart fprintd.service";
        };
      };
    };
}
