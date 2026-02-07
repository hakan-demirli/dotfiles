{ lib, ... }:
{
  flake.modules.nixos.services-ntfy = {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "http://localhost:8111";
        listen-http = "0.0.0.0:8111";
        enable-login = false;
        auth-default-access = "read-write";
      };
    };

    systemd.services.ntfy-sh.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "ntfy-sh";
      Group = "ntfy-sh";
    };

    users.users.ntfy-sh = {
      isSystemUser = true;
      group = "ntfy-sh";
      description = "ntfy-sh service user";
    };
    users.groups.ntfy-sh = { };

    environment.persistence."/persist/system".directories = [
      {
        directory = "/var/lib/ntfy-sh";
        user = "ntfy-sh";
        group = "ntfy-sh";
        mode = "0700";
      }
    ];
  };
}
