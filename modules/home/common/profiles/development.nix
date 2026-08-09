_: {
  programs = {
    gh = {
      enable = true;
      gitCredentialHelper.enable = false;
      settings.git_protocol = "https";
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
