{
  lib,
  host,
  cluster,
  ...
}:
let
  hostCluster =
    if cluster.hostToCluster ? ${host.id} then
      cluster.clusters.${cluster.hostToCluster.${host.id}}
    else
      throw "personal-server-dev: host '${host.id}' is not attached to any cluster.";

  controllers = hostCluster.scheduler.controllers;
  masterHostname =
    if controllers == [ ] then
      throw "personal-server-dev: cluster '${hostCluster.id}' has no scheduler.controllers declared."
    else
      builtins.head controllers;

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
    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    slurm-cluster = {
      enable = true;
      isMaster = false;
      inherit masterHostname;
      inherit clusterNodes;
    };
  };

  networking.networkmanager.enable = true;
  programs.nix-ld.enable = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
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
