_: {
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          nixVersions.latest
          nix-output-monitor
          nixfmt
          statix
          deadnix
          taplo
          yj
          jq
          remarshal
          fzf
          sops
          age
          ssh-to-age
          openssh
          rsync
          nixos-rebuild
          ipmitool
          gitMinimal
        ];
      };
    };
}
