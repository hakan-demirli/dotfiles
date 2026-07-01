_: {
  system.impermanence.persistentDirs = [ "/persist/xilinx" ];

  systemd.tmpfiles.rules = [
    "d /persist/xilinx 0755 emre users -"
  ];
}
