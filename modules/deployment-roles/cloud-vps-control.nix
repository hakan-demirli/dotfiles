{
  config,
  host,
  inputs,
  cluster,
  lib,
  pkgs,
  ...
}:
let
  ownerId = host.ownership.owner or null;
  ownerUser = if ownerId == null then null else (cluster.users.${ownerId} or null);
  primaryAccount = if ownerUser == null then null else ownerUser.system_account;
  primaryUser = if primaryAccount == null then "emre" else primaryAccount.username;
  primaryHome = "/home/${primaryUser}";
  downloadDir = "${primaryHome}/Downloads";
  incompleteDir = "${downloadDir}/.incomplete";
  mediaDir = "${downloadDir}/media";
  tailnetUrl = "http://100.64.0.1";
  forgeDomain = "${host.id}.ts.${config.services.tailscale.loginServerHost}";
  impermanenceEnabled = host.impermanence.enable or false;

in
{
  services = {
    sops.bootstrap.passwordAccount = "root";

    openssh.settings.PermitRootLogin = lib.mkForce "no";

    headscale-server = {
      enable = true;
      serverUrl = "sshr.polarbearvuzi.com";
      allowedUDPPorts = [
        3478
        41641
      ];
    };

    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    reverse-ssh-server = {
      enable = true;
      tailnetOnly = true;
      allowedTCPPorts = [
        42001
        42002
        42003
        42004
        42005
        42006
        42007
        42008
        42009
        42010
      ];
    };

    slurm-cluster.enable = true;
    cluster-slurm-metrics.enable = true;

    transmission-cluster = {
      inherit downloadDir incompleteDir;
      openPeerPorts = false;
      rpcWhitelist = "127.0.0.1,::1,100.64.*.*";
    };

    homepage.extraServices = [
      {
        name = "Transmission";
        url = "${tailnetUrl}:9091/transmission/web/";
      }
      {
        name = "Grafana";
        url = "${tailnetUrl}:${toString config.services.cluster-grafana.listenPort}/";
      }
      {
        name = "VictoriaMetrics";
        url = "${tailnetUrl}:${toString config.services.cluster-victoriametrics.listenPort}/vmui/";
      }
      {
        name = "VictoriaLogs";
        url = "${tailnetUrl}:${toString config.services.cluster-victorialogs.listenPort}/select/vmui/";
      }
      {
        name = "Alertmanager";
        url = "${tailnetUrl}:${toString config.services.cluster-alertmanager.listenPort}/";
      }
      {
        name = "Alert rules";
        url = "${tailnetUrl}:${toString config.services.cluster-vmalert.listenPort}/";
      }
      {
        name = "Forgejo";
        url = "${tailnetUrl}:${toString config.cluster.services.forgejo.port}/";
      }
    ];

    homepage.extraLan = [
      {
        name = "plug-0";
        url = "http://plug-0.lan";
      }
    ];

    cluster-harmonia = {
      firewallInterface = config.services.tailscale.interfaceName;
      signKey = {
        source = "sops";
        sopsKeyName = "nix-serve-key";
      };
    };

    cluster-victoriametrics.targetDomain = "ts.sshr.polarbearvuzi.com";

    cluster-forgejo = {
      domain = forgeDomain;
      listenPort = config.cluster.services.forgejo.port;
      admin = {
        username = inputs.self.lib.forge.owner;
        email = "hakan-demirli@${forgeDomain}";
        password = {
          source = "sops";
          sopsKeyName = "forgejo/admin-password";
        };
      };
    };

    # Fleet hosts fetch the flake without credentials; the port is tailnet-only.
    forgejo.settings.service.REQUIRE_SIGNIN_VIEW = lib.mkForce false;

    forgejo-repositories = {
      repositories = {
        dotfiles = { };
        infra-lib = { };
        NUR = { };
        NURP.private = true;
        state.private = true;
        code_templates.private = true;
      };
      sshKeys = lib.unique (
        lib.concatLists (
          lib.mapAttrsToList (
            _: user:
            lib.optionals (lib.elem "fleet" user.admin_scopes && !(user.archived or false)) user.keys.ssh
          ) cluster.users
        )
      );
    };

    cliproxyapi = {
      enable = true;
      # v8.0.53 keeps Fable-only 429s model-scoped (router-for-me/CLIProxyAPI#7197);
      # older releases cool the whole credential and block every model on it.
      package = pkgs.cliproxyapi.overrideAttrs (_: {
        version = "8.0.53";
        src = pkgs.fetchFromGitHub {
          owner = "router-for-me";
          repo = "CLIProxyAPI";
          tag = "v8.0.53";
          hash = "sha256-XvrI11A4C4oe9vAe6j9uLxmKDZ989jZnAXHNrC0k1yA=";
        };
        vendorHash = "sha256-YZf38f5X+z/rICUQKHuzmZxkPH3AAap6XkIho/injVA=";
      });
      settings = {
        config-version = 8;
        server = {
          host = "";
          inherit (config.cluster.services.cliproxyapi) port;
        };
        access.api-keys = [ { _secret = config.sops.secrets."cliproxyapi/api-key".path; } ];
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
      };
    };
  };

  environment.persistence = lib.mkIf impermanenceEnabled {
    "/persist/system".directories = [
      {
        directory = "/var/lib/cliproxyapi";
        inherit (config.services.cliproxyapi) user group;
        mode = "0700";
      }
    ];
  };

  sops.secrets."cliproxyapi/api-key" = { };

  systemd.services.cliproxyapi = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  users.users.${primaryUser}.linger = true;

  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults:%wheel rootpw
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${downloadDir} 0755 ${primaryUser} users -"
    "d ${incompleteDir} 0755 ${primaryUser} users -"
    "d ${mediaDir} 0755 ${primaryUser} users -"
    "a+ ${primaryHome} - - - - u:transmission:x,m::x"
    "a+ ${downloadDir} - - - - u:transmission:rwx,m::rwx"
    "A+ ${incompleteDir} - - - - u:transmission:rwx,m::rwx"
    "a+ ${incompleteDir} - - - - d:u:transmission:rwx,d:m::rwx"
    "a+ ${primaryHome} - - - - u:jellyfin:x,m::x"
    "a+ ${downloadDir} - - - - u:jellyfin:rx,m::rwx"
    "A+ ${mediaDir} - - - - u:jellyfin:rX,m::r-x"
  ];

}
