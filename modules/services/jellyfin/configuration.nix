_: {
  flake.modules.nixos.services-jellyfin =
    { pkgs, config, ... }:
    let
      inherit (config.system.user) username;
    in
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      environment.systemPackages = [ pkgs.acl ];

      system.activationScripts.jellyfinAccess.text = ''
        ${pkgs.acl}/bin/setfacl -m u:jellyfin:x /home/${username}
        ${pkgs.acl}/bin/setfacl -m u:jellyfin:rx /home/${username}/Downloads
        ${pkgs.acl}/bin/setfacl -R -m u:jellyfin:rX /home/${username}/Downloads/media
      '';

      environment.persistence."/persist/system".directories = [
        {
          directory = "/var/lib/jellyfin";
          user = "jellyfin";
          group = "jellyfin";
          mode = "0700";
        }
      ];
    };
}
