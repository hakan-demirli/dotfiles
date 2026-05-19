_: {
  flake.modules.nixos.services-jellyfin =
    { config, ... }:
    let
      inherit (config.system.user) username;
    in
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      systemd.tmpfiles.rules = [
        "d /home/${username}/Downloads/media 0755 ${username} users -"
        "a+ /home/${username} - - - - u:jellyfin:x"
        "a+ /home/${username}/Downloads - - - - u:jellyfin:rx"
        "A+ /home/${username}/Downloads/media - - - - u:jellyfin:rX"
      ];

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
