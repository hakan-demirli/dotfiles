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
  tailnetAddress = "100.64.0.1";
  tailnetUrl = "http://${tailnetAddress}";
  inherit (inputs.self.lib) tailnetZone;
  sites = {
    ${tailnetZone} = config.services.homepage.port;
    ${inputs.self.lib.forge.site} = config.cluster.services.forgejo.port;
    "ci.${tailnetZone}" = config.cluster.services.nixbot.port;
  };
  forgeDomain = "${host.id}.ts.${config.services.tailscale.loginServerHost}";
  impermanenceEnabled = host.impermanence.enable or false;

in
{
  services = {
    sops.bootstrap.passwordAccount = "root";

    openssh.settings.PermitRootLogin = lib.mkForce "no";

    headscale.settings.dns = {
      extra_records = lib.mapAttrsToList (name: _: {
        inherit name;
        type = "A";
        value = tailnetAddress;
      }) sites;
      # Clients route each listed name to Tailscale, ahead of a network that claims the zone.
      search_domains = lib.attrNames sites;
    };

    # The public listener also carries these names; only tailnet peers are served.
    caddy.virtualHosts = lib.mapAttrs' (
      name: port:
      lib.nameValuePair "http://${name}" {
        extraConfig = ''
          @outside not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
          abort @outside
          reverse_proxy 127.0.0.1:${toString port}
        '';
      }
    ) sites;

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

    homepage = {
      extraServices = [
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
        {
          name = "nixbot";
          url = "${tailnetUrl}:${toString config.cluster.services.nixbot.port}/";
        }
      ]
      ++ map (id: {
        name = "OpenCode ${id}";
        url = "${inputs.self.lib.opencode.url id}/";
      }) inputs.self.lib.opencode.hosts;

      extraAddresses = [
        {
          name = "Deploy Plan";
          url = config.cluster.autoUpgrade.planUrl;
        }
      ];

      extraLan = [
        {
          name = "plug-0";
          url = "http://plug-0.lan";
        }
      ];
    };

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
      # v8.0.63 presents Claude Code 2.1.321, which Claude Fable 5.2 requires.
      package = pkgs.cliproxyapi.overrideAttrs (_: {
        version = "8.0.64";
        src = pkgs.fetchFromGitHub {
          owner = "router-for-me";
          repo = "CLIProxyAPI";
          tag = "v8.0.64";
          hash = "sha256-X/G9jGelmB0RUnc8Eyw5QdXmBVywz2610TknILzkV8c=";
        };
        vendorHash = "sha256-02Qqrs9lQ0kE+Tnk/SWvlkLXGSh8RQPxRawFZogRYNc=";
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
