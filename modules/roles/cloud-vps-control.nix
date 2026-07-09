{
  lib,
  host,
  cluster,
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

  hostCluster =
    if cluster.hostToCluster ? ${host.id} then
      cluster.clusters.${cluster.hostToCluster.${host.id}}
    else
      throw "cloud-vps-control: host '${host.id}' is not attached to any cluster.";

  nodeAttrsFor =
    hid:
    let
      h = cluster.hosts.${hid};
    in
    {
      hostName = hid;
      sockets = h.hardware.cpu_sockets;
      coresPerSocket = h.hardware.cpu_cores_per_socket;
      threadsPerCore = h.hardware.cpu_threads_per_core;
      cpuLogicalCount = h.hardware.cpu_logical_count;
      ramMb = h.hardware.ram_gib * 1024;
    };

  clusterNodes = map nodeAttrsFor cluster.hostsByCluster.${hostCluster.id};
in
{
  services = {
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

    slurm-cluster = {
      enable = true;
      isMaster = true;
      masterHostname = host.id;
      inherit clusterNodes;
    };

    transmission-cluster = {
      inherit downloadDir incompleteDir;
      rpcWhitelist = "127.0.0.1,::1,100.64.*.*";
    };

    homepage.extraServices = [
      {
        name = "Transmission";
        url = "http://100.64.0.1:9091/transmission/web/";
      }
    ];

    cluster-harmonia.signKey.source = "sops";

    cluster-victoriametrics.targetDomain = "ts.sshr.polarbearvuzi.com";
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

  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
}
