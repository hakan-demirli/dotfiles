_: {
  flake.modules.nixos.services-jellyfin =
    { pkgs, ... }:
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      environment.systemPackages = [ pkgs.acl ];

      system.activationScripts.jellyfinAccess.text = ''
        ${pkgs.acl}/bin/setfacl -m u:jellyfin:x /home/emre
        ${pkgs.acl}/bin/setfacl -m u:jellyfin:rx /home/emre/Downloads
        ${pkgs.acl}/bin/setfacl -R -m u:jellyfin:rX /home/emre/Downloads/media
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
