_: {
  programs = {
    gh = {
      enable = true;
      gitCredentialHelper.enable = false;
      settings = {
        git_protocol = "https";
        aliases.prcu = "pr create --base unstable --fill";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
