{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "${config.xdg.stateHome}/cliproxyapi";
  configFile = "${config.xdg.configHome}/cliproxyapi/config.yaml";
  settings = (pkgs.formats.yaml { }).generate "cliproxyapi.yaml" {
    config-version = 8;
    server = {
      host = "";
      port = 8317;
    };
    management = {
      secret-key = "";
      disable-control-panel = true;
    };
    routing = {
      strategy = "fill-first";
      session-affinity = true;
      session-affinity-rebind-on = "quota";
      cooldown.save-cooldown-status = true;
    };
    oauth.auth-dir = "${stateDir}/auths";
  };
in
{
  home = {
    packages = [ pkgs.cliproxyapi ];
    activation.cliproxyapiState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 700 ${lib.escapeShellArg "${stateDir}/auths"}
    '';
  };

  xdg.configFile."cliproxyapi/config.yaml".source = settings;

  systemd.user.services.cliproxyapi = {
    Unit = {
      Description = "CLIProxyAPI subscription proxy on port 8317";
      X-Restart-Triggers = [ "${settings}" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.cliproxyapi} -config ${configFile}";
      Restart = "always";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
