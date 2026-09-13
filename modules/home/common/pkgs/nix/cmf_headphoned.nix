{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (packages: [ packages.dbus-fast ]);

  cmfHeadphoned = pkgs.writeShellApplication {
    name = "cmf-headphoned";
    runtimeInputs = [ python ];
    text = ''
      exec python3 ${../bin/cmf_headphoned.py} "$@"
    '';
  };
in
{
  home.packages = [ cmfHeadphoned ];

  systemd.user.services.cmf-headphoned = {
    Unit = {
      Description = "CMF Headphone Pro battery and noise control";
      PartOf = [ "default.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${cmfHeadphoned}/bin/cmf-headphoned";
      Restart = "always";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
