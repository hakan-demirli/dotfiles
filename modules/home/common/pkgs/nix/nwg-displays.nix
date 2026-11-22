{
  config,
  lib,
  ...
}:
let
  stateDir = "${config.xdg.stateHome}/nwg-displays";
  link = path: config.lib.file.mkOutOfStoreSymlink "${stateDir}/${path}";
in
{
  xdg.configFile = {
    "hypr/monitors.conf".source = link "hypr/monitors.conf";
    "hypr/monitors.lua".source = link "hypr/monitors.lua";
    "hypr/workspaces.conf".source = link "hypr/workspaces.conf";
    "hypr/workspaces.lua".source = link "hypr/workspaces.lua";
    nwg-displays.source = link "config";
  };

  home.activation.configureNwgDisplays = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m 700 ${
      lib.escapeShellArgs [
        "${stateDir}/hypr"
        "${stateDir}/config"
      ]
    }
  '';
}
