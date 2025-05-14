{
  pkgs,
  username ? throw "You must specify a username",
  ...
}:
let
  scriptHome = "/home/${username}";
  secretsDir = "${scriptHome}/Desktop/dotfiles/secrets";
  gitConfigDir = "${scriptHome}/.config/git";
  checkFile = "${secretsDir}/git_keys";
  gitcryptMagic = "GITCRYPT";

  setupScriptContent = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Checking encryption status of ${checkFile}..."
    if [ -f "${checkFile}" ] && [ -s "${checkFile}" ] && \
       ! ${pkgs.coreutils}/bin/head -c ${toString (builtins.stringLength gitcryptMagic)} "${checkFile}" | ${pkgs.gnugrep}/bin/grep -q -F "${gitcryptMagic}"; then
      echo "Secrets file ${checkFile} appears decrypted. Creating symlinks in ${gitConfigDir}..."
      ${pkgs.coreutils}/bin/mkdir -p "${gitConfigDir}" # Ensure target dir exists
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_tokens" "${gitConfigDir}/git_tokens"
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_users" "${gitConfigDir}/git_users"
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_keys" "${gitConfigDir}/git_keys"

      ${pkgs.coreutils}/bin/ln -sfnT "${secretsDir}/.ssh" "${scriptHome}/.ssh"
      ${pkgs.coreutils}/bin/chmod 700 "${scriptHome}/.ssh"
    else
      echo "Secrets file ${checkFile} not found, empty, or appears encrypted. Skipping."
    fi
    exit 0
  '';

  setupScript = pkgs.writeShellScriptBin "setup-git-symlinks-script-${username}" setupScriptContent;
in
{
  systemd.services."setup-git-symlinks-${username}" = {
    description = "Deploy secrets for ${username} if they are decrypted";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      Group = "users";

      ExecStart = "${setupScript}/bin/setup-git-symlinks-script-${username}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.paths."setup-git-symlinks-${username}" = {
    description = "Path unit to watch for decrypted git secrets for ${username}";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = checkFile;
      Unit = "setup-git-symlinks-${username}.service";
    };
  };
}
