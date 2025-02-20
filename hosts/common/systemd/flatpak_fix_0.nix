_: {
  systemd = {
    # https://github.com/NixOS/nixpkgs/issues/189851
    user = {
      extraConfig = ''
        DefaultEnvironment="PATH=/run/current-system/sw/bin"
      '';
    };
  };
}
