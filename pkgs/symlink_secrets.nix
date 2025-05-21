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
  sleepInterval = 20;

  setupScriptContent = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Starting setup-git-symlinks script for ${username}..."

    while true; do
      echo "Checking for existence and non-emptiness of ${checkFile}..."
      if [ -f "${checkFile}" ] && [ -s "${checkFile}" ]; then
        echo "File ${checkFile} found and is not empty. Proceeding."
        break
      else
        echo "File ${checkFile} not found or is empty. Retrying in ${toString sleepInterval} seconds..."
        ${pkgs.coreutils}/bin/sleep ${toString sleepInterval}
      fi
    done

    echo "Checking encryption status of ${checkFile}..."
    if ! (${pkgs.coreutils}/bin/head -c ${toString (builtins.stringLength gitcryptMagic)} "${checkFile}" | ${pkgs.gnugrep}/bin/grep -q -F "${gitcryptMagic}"); then
      echo "Secrets file ${checkFile} appears decrypted. Creating symlinks in ${gitConfigDir}..."
      ${pkgs.coreutils}/bin/mkdir -p "${gitConfigDir}"
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_tokens" "${gitConfigDir}/git_tokens"
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_users" "${gitConfigDir}/git_users"
      ${pkgs.coreutils}/bin/ln -sfn "${secretsDir}/git_keys" "${gitConfigDir}/git_keys"

      ${pkgs.coreutils}/bin/ln -sfnT "${secretsDir}/.ssh" "${scriptHome}/.ssh"
      ${pkgs.coreutils}/bin/chmod 700 "${scriptHome}/.ssh"
      echo "Symlinks created."
    else
      echo "Secrets file ${checkFile} appears encrypted (contains '${gitcryptMagic}') or grep check failed. Skipping symlink creation."
    fi

    echo "setup-git-symlinks script finished."
    exit 0
  '';

  setupScript = pkgs.writeShellScriptBin "setup-git-symlinks-script-${username}" setupScriptContent;
in
{
  systemd.services."setup-git-symlinks-${username}" = {
    description = "Deploy secrets for ${username} if/when they are decrypted (retries until file exists)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "time-sync.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = username;
      ExecStart = "${setupScript}/bin/setup-git-symlinks-script-${username}";
      StandardOutput = "journal";
      StandardError = "journal";
      TimeoutStartSec = "infinity";
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
