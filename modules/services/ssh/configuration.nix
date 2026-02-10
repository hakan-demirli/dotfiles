_: {
  flake.modules.nixos.services-ssh =
    { config, lib, ... }:
    let
      cfg = config.services.ssh;
    in
    {
      options.services.ssh = {
        allowPasswordAuth = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow password authentication for SSH";
        };
        rootSshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys for root user";
        };
      };

      config = {
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = cfg.allowPasswordAuth;
            PermitRootLogin = "prohibit-password";
            KbdInteractiveAuthentication = false;
            UsePAM = true;
            StreamLocalBindUnlink = "yes";
          };
        };

        users.users.root.openssh.authorizedKeys.keys = cfg.rootSshKeys;
      };
    };
}
