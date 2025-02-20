_: {
  imports = [
    ./services/tlp.nix
  ];

  # $ nix search wget
  powerManagement = {
    enable = true;
    # cpuFreqGovernor = "schedutil";
  };
}
