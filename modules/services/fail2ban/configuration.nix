_: {
  flake.modules.nixos.services-fail2ban = _: {
    services.fail2ban = {
      enable = true;

      bantime = "4h";

      bantime-increment = {
        enable = true;
        multipliers = "1 2 4 8 16 32 64";
        maxtime = "168h"; # 1 week
      };

      jails = {
        sshd = {
          settings = {
            enable = true;
            backend = "systemd";
            maxretry = 5;
            findtime = "60m";
          };
        };
      };
    };
  };
}
