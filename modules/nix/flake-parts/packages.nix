{
  inputs,
  ...
}:
{
  # Packages output for portable barebone environment as buildEnv
  perSystem = { pkgs, system, ... }:
  let
    barebonePackages = with pkgs; [
      # dev-essentials
      bat
      delta
      fd
      fzf
      git
      jq
      parallel-full
      ripgrep
      tmux
      trash-cli
      tree
      yazi
      starship

      # editors
      helix
      neovim
      vim

      # lsp
      clang-tools
      gnumake
      lua-language-server
      nixd
      nixfmt-rfc-style
      nodePackages_latest.bash-language-server
      pyright
      python3
      ruff
      shfmt
      taplo
      yaml-language-server

      # tools-cli
      rsync
      ouch
      zip
      openssl

      # additional essentials
      ncurses
      direnv
    ];
  in
  {
    packages.barebone = pkgs.buildEnv {
      name = "barebone";
      paths = barebonePackages;
    };
  };
}
