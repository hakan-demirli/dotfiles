{ pkgs, inputs, ... }:
{
  home = {
    packages = [ pkgs.tea ];
    sessionVariables.GITEA_INSTANCE_URL = inputs.self.lib.forge.web;
  };

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
