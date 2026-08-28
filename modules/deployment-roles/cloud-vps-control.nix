{
  config,
  host,
  cluster,
  lib,
  ...
}:
let
  ownerId = host.ownership.owner or null;
  ownerUser = if ownerId == null then null else (cluster.users.${ownerId} or null);
  primaryAccount = if ownerUser == null then null else ownerUser.system_account;
  primaryUser = if primaryAccount == null then "emre" else primaryAccount.username;
  primaryHome = "/home/${primaryUser}";
  downloadDir = "${primaryHome}/Downloads";
  incompleteDir = "${downloadDir}/.incomplete";
  mediaDir = "${downloadDir}/media";
  tailnetUrl = "http://100.64.0.1";

in
{
  services = {
    sops.bootstrap.passwordAccount = "root";

    openssh.settings.PermitRootLogin = lib.mkForce "no";

    headscale-server = {
      enable = true;
      serverUrl = "sshr.polarbearvuzi.com";
      allowedUDPPorts = [
        3478
        41641
      ];
    };

    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    reverse-ssh-server = {
      enable = true;
      allowedTCPPorts = [
        42001
        42002
        42003
        42004
        42005
        42006
        42007
        42008
        42009
        42010
      ];
    };

    slurm-cluster.enable = true;

    transmission-cluster = {
      inherit downloadDir incompleteDir;
      rpcWhitelist = "127.0.0.1,::1,100.64.*.*";
    };

    homepage.extraServices = [
      {
        name = "Transmission";
        url = "${tailnetUrl}:9091/transmission/web/";
      }
      {
        name = "Grafana";
        url = "${tailnetUrl}:${toString config.services.cluster-grafana.listenPort}/";
      }
      {
        name = "VictoriaMetrics";
        url = "${tailnetUrl}:${toString config.services.cluster-victoriametrics.listenPort}/vmui/";
      }
      {
        name = "VictoriaLogs";
        url = "${tailnetUrl}:${toString config.services.cluster-victorialogs.listenPort}/select/vmui/";
      }
      {
        name = "Alertmanager";
        url = "${tailnetUrl}:${toString config.services.cluster-alertmanager.listenPort}/";
      }
      {
        name = "Alert rules";
        url = "${tailnetUrl}:${toString config.services.cluster-vmalert.listenPort}/";
      }
    ];

    cluster-harmonia.signKey = {
      source = "sops";
      sopsKeyName = "nix-serve-key";
    };

    cluster-victoriametrics.targetDomain = "ts.sshr.polarbearvuzi.com";
  };

  users.users.${primaryUser}.linger = true;

  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults:%wheel rootpw
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${downloadDir} 0755 ${primaryUser} users -"
    "d ${incompleteDir} 0755 ${primaryUser} users -"
    "d ${mediaDir} 0755 ${primaryUser} users -"
    "a+ ${primaryHome} - - - - u:transmission:x,m::x"
    "a+ ${downloadDir} - - - - u:transmission:rwx,m::rwx"
    "A+ ${incompleteDir} - - - - u:transmission:rwx,m::rwx"
    "a+ ${incompleteDir} - - - - d:u:transmission:rwx,d:m::rwx"
    "a+ ${primaryHome} - - - - u:jellyfin:x,m::x"
    "a+ ${downloadDir} - - - - u:jellyfin:rx,m::rwx"
    "A+ ${mediaDir} - - - - u:jellyfin:rX,m::r-x"
  ];

}
