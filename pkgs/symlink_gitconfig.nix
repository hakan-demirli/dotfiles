{ pkgs, ... }:
let
  scriptUser = "emre";
  scriptHome = "/home/${scriptUser}";
  gitSecretsPath = "${scriptHome}/Desktop/dotfiles/secrets";
  gitConfigPath = "${scriptHome}/.config/git";
in
{
  systemd.services = {
    setup-git-symlinks = {
      description = "Create Git config symlinks for ${scriptUser}";
      after = [
        "network-online.target"
        "local-fs.target"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;

        User = scriptUser;
        Group = "users";

        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${gitConfigPath}";

        ExecStart = ''
          ${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/ln -sf ${gitSecretsPath}/git_tokens ${gitConfigPath}/git_tokens && \
                                    ${pkgs.coreutils}/bin/ln -sf ${gitSecretsPath}/git_users ${gitConfigPath}/git_users && \
                                    ${pkgs.coreutils}/bin/ln -sf ${gitSecretsPath}/git_keys ${gitConfigPath}/git_keys'
        '';

        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

  };
}
