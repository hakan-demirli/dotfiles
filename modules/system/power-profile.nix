{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.powerProfile;

  modes = [
    "turbo"
    "balanced"
    "silent"
  ];

  mkRootScript =
    args:
    pkgs.writeShellApplication (
      args
      // {
        inheritPath = false;
        bashOptions = [
          "nounset"
          "pipefail"
        ];
      }
    );

  backend = mkRootScript {
    name = "power-profile-backend";
    inherit (cfg) runtimeInputs;
    text = builtins.readFile cfg.backend;
  };

  powerProfile = mkRootScript {
    name = "power-profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    runtimeEnv.POWER_PROFILE_BACKEND = lib.getExe backend;
    text = builtins.readFile ./power-profile.sh;
  };
in
{
  options.hardware.powerProfile = {
    backend = lib.mkOption {
      type = lib.types.path;
      description = ''
        Board script behind power-profile. It implements `apply MODE`,
        `status`, `rpm`, `commands`, `run COMMAND...` and `help`. power-profile
        holds the lock and runs it as root, except for rpm, commands and help.
      '';
    };

    runtimeInputs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages on the PATH of the board script. It inherits no other PATH.";
    };
  };

  config = {
    environment.systemPackages = [ powerProfile ];

    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = map (command: {
          command = "${lib.getExe powerProfile} ${command}";
          options = [
            "NOPASSWD"
            "NOSETENV"
          ];
        }) ([ "status" ] ++ modes);
      }
    ];

    systemd.tmpfiles.rules = [ "d /run/power-profile 0755 root root -" ];
  };
}
