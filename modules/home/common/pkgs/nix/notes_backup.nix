{
  repoPath ? null,
  notesDir ? "scratchpads",
  branch,
  remote,
  onCalendar ? "*:0/15",
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  resolvedRepoPath =
    if repoPath == null then "${config.home.homeDirectory}/Desktop/infra/state" else repoPath;
  backup = pkgs.writeShellApplication {
    name = "notes-backup";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
      pkgs.util-linux
      config.homeSops.bootstrap
    ];
    text = builtins.readFile ../bin/notes-backup.sh;
  };
in
{
  options.home.notesRepository = lib.mkOption {
    type = lib.types.submodule {
      options = {
        path = lib.mkOption { type = lib.types.str; };
        directory = lib.mkOption { type = lib.types.str; };
        branch = lib.mkOption { type = lib.types.str; };
        remote = lib.mkOption { type = lib.types.str; };
      };
    };
    readOnly = true;
    internal = true;
    description = "The personal notes checkout published by the backup service.";
  };
  config = {
    home = {
      notesRepository = {
        path = resolvedRepoPath;
        directory = notesDir;
        inherit branch remote;
      };
      file.".local/share/${notesDir}".source =
        config.lib.file.mkOutOfStoreSymlink "${resolvedRepoPath}/${notesDir}";
    };
    systemd.user = {
      services.notes-backup = {
        Unit = {
          Description = "Back up ${notesDir} to ${branch}";
          Wants = [ "sops-nix.service" ];
          After = [ "sops-nix.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${backup}/bin/notes-backup ${lib.escapeShellArg resolvedRepoPath} ${lib.escapeShellArg branch} ${lib.escapeShellArg remote} ${lib.escapeShellArg notesDir}";
          TimeoutStartSec = 120;
        };
      };
      timers.notes-backup = {
        Unit.Description = "Timer for notes-backup";
        Timer = {
          OnStartupSec = "1min";
          OnCalendar = onCalendar;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
