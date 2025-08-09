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

  # --- New: A separate script for user-specific actions ---
  userActionsScript = pkgs.writeShellScriptBin "setup-user-symlinks" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Running as user: $(id -un)"

    # Create git config directory and symlinks
    mkdir -p "${gitConfigDir}"
    ln -sfn "${secretsDir}/git_tokens" "${gitConfigDir}/git_tokens"
    ln -sfn "${secretsDir}/git_users" "${gitConfigDir}/git_users"
    ln -sfn "${secretsDir}/git_keys" "${gitConfigDir}/git_keys"
    echo "Git config symlinks created successfully."

    # Create .ssh symlink ONLY if it doesn't already exist
    if [ ! -e "${scriptHome}/.ssh" ]; then
      ln -sfnT "${secretsDir}/.ssh" "${scriptHome}/.ssh"
      echo ".ssh symlink created."
    fi
  '';

  # --- The main script, now simplified ---
  setupScriptContent = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Starting setup-git-symlinks script for ${username}..."

    # Check if secrets are decrypted (runs as root)
    while true; do
      if [ -f "${checkFile}" ] && [ -s "${checkFile}" ]; then break; fi
      echo "Secrets not ready, retrying in ${toString sleepInterval}s..."
      ${pkgs.coreutils}/bin/sleep ${toString sleepInterval}
    done

    if (${pkgs.coreutils}/bin/head -c ${toString (builtins.stringLength gitcryptMagic)} "${checkFile}" | ${pkgs.gnugrep}/bin/grep -q -F "${gitcryptMagic}"); then
      echo "Secrets file appears encrypted. Skipping."
      exit 0
    fi
    
    echo "Secrets appear decrypted. Executing user-level setup."

    # Execute the user-specific script as the user
    ${pkgs.sudo}/bin/sudo -u ${username} ${userActionsScript}/bin/setup-user-symlinks

    # Handle the case where .ssh is an existing DIRECTORY that needs to be mounted over
    if [ -d "${scriptHome}/.ssh" ] && [ ! -L "${scriptHome}/.ssh" ]; then
      echo "Existing .ssh directory found. Binding secrets over it."
      ${pkgs.util-linux}/bin/mount --bind "${secretsDir}/.ssh" "${scriptHome}/.ssh"
      ${pkgs.coreutils}/bin/chown -R ${username}:${username} "${scriptHome}/.ssh" 2>/dev/null || true
      echo "Mounted ${secretsDir}/.ssh over ${scriptHome}/.ssh"
    fi

    # Set final permissions (always safe for root to do)
    ${pkgs.coreutils}/bin/chmod 700 "${scriptHome}/.ssh"
    ${pkgs.coreutils}/bin/chmod 400 "${scriptHome}/.ssh/id_ed25519" 2>/dev/null || true
    ${pkgs.coreutils}/bin/chmod 644 "${scriptHome}/.ssh/id_ed25519.pub" 2>/dev/null || true
    echo "SSH permissions finalized."
  '';

  setupScript = pkgs.writeShellScriptBin "setup-git-symlinks-script-${username}" setupScriptContent;
in
{
  systemd.services."setup-git-symlinks-${username}" = {
    description = "Deploy secrets for ${username} if/when they are decrypted (retries until file exists)";
    wantedBy = [ "multi-user.target" ];
    after = [ "time-sync.target" ];
    restartTriggers = [ setupScript ]; # Keeps this service up-to-date on rebuild
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
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
