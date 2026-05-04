_: {
  flake.modules.nixos.services-transmission =
    { config, pkgs, ... }:
    let
      inherit (config.system.user) username;
      downloadDir = "/home/${username}/Downloads";
      incompleteDir = "/home/${username}/Downloads/.incomplete";
    in
    {
      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        openPeerPorts = true;
        openRPCPort = false;
        performanceNetParameters = true;
        settings = {
          rpc-bind-address = "0.0.0.0";
          rpc-port = 9091;
          rpc-host-whitelist-enabled = false;
          rpc-whitelist-enabled = true;
          rpc-whitelist = "127.0.0.1,::1,100.64.*.*";
          download-dir = downloadDir;
          incomplete-dir = incompleteDir;
          incomplete-dir-enabled = true;
          trash-original-torrent-files = true;
          umask = 2;
          watch-dir-enabled = false;
        };
      };

      services.homepage.extraServices = [
        {
          name = "Transmission";
          url = "http://100.64.0.1:9091/transmission/web/";
        }
      ];

      environment.systemPackages = [ pkgs.acl ];

      environment.persistence."/persist/system".directories = [
        {
          directory = "/var/lib/transmission";
          user = "transmission";
          group = "transmission";
          mode = "0750";
        }
      ];

      system.activationScripts.transmissionAccess.text = ''
        ${pkgs.acl}/bin/setfacl -m u:transmission:x /home/${username}
        ${pkgs.acl}/bin/setfacl -m u:transmission:rwx /home/${username}/Downloads
        ${pkgs.acl}/bin/setfacl -R -m u:transmission:rwx ${incompleteDir}
      '';

      systemd.tmpfiles.rules = [
        "d ${downloadDir} 0755 ${username} users -"
        "d ${incompleteDir} 0755 ${username} users -"
      ];
    };
}
