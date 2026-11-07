{
  config,
  lib,
  pkgs,
  inputs,
  host,
  ...
}:
let
  forge = config.services.cluster-forgejo;
  forgejo = config.services.forgejo;
  inherit (config.cluster.services.nixbot) port;

  bot = "nixbot";
  stateDir = "/var/lib/forge-ci";
  tokenFile = "${stateDir}/forgejo-token";
  impermanenceEnabled = host.impermanence.enable or false;

  buildSystems = lib.unique (
    [ pkgs.stdenv.hostPlatform.system ]
    ++ lib.concatMap (machine: machine.systems) config.nix.buildMachines
  );

  requiredStatuses = [
    "nixbot/nix-eval"
    "nixbot/nix-build"
  ];

  linearHistory = {
    allow_merge_commits = false;
    allow_rebase = true;
    allow_rebase_explicit = false;
    allow_squash_merge = true;
    allow_fast_forward_only_merge = true;
    default_merge_style = "rebase";
    default_delete_branch_after_merge = true;
  };

  mintToken = pkgs.writeShellApplication {
    name = "forge-ci-token";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      forgejo.package
    ];
    text = ''
      api=${lib.escapeShellArg "http://127.0.0.1:${toString forge.listenPort}/api/v1"}
      token_file=${lib.escapeShellArg tokenFile}

      if [[ -s $token_file ]] \
        && curl -fsS -o /dev/null -H "Authorization: token $(<"$token_file")" "$api/user"; then
        exit 0
      fi

      echo "forge-ci-token: minting a Forgejo token for ${bot}"
      forgejo admin user generate-access-token \
        --username ${bot} \
        --token-name "${bot}-$(date +%s)" \
        --scopes write:repository,write:issue,read:user \
        --raw > "$token_file.new"
      mv "$token_file.new" "$token_file"
    '';
  };
in
{
  imports = [ inputs.nixbot.nixosModules.nixbot ];

  services = {
    forgejo.settings.webhook.ALLOWED_HOST_LIST = "loopback";

    forgejo-repositories = {
      users.${bot}.email = "${bot}@${forge.domain}";

      repositories = {
        dotfiles = {
          defaultBranch = "unstable";
          topics = [ bot ];
          collaborators.${bot} = "admin";
          settings = linearHistory;
          branchProtections = {
            unstable = {
              enable_push = false;
              enable_status_check = true;
              status_check_contexts = requiredStatuses;
              required_approvals = 0;
              apply_to_admins = true;
            };
            main = {
              enable_push = true;
              enable_push_whitelist = true;
              push_whitelist_usernames = [ bot ];
              apply_to_admins = true;
            };
          };
        };

        infra-lib = {
          topics = [ bot ];
          collaborators.${bot} = "admin";
        };
      };
    };

    nixbot = {
      enable = true;
      inherit (forge) domain;
      inherit port buildSystems;
      evalSystems = buildSystems;
      nginx.enable = false;
      webhookBaseUrl = "http://127.0.0.1:${toString port}/";
      admins = [ "gitea:${forge.admin.username}" ];
      # The UI is reachable from the fleet's tailnet only.
      allowUnauthenticatedControl = true;
      evalWorkerCount = 2;
      evalMaxMemorySize = 4096;

      gitea = {
        enable = true;
        instanceUrl = "http://127.0.0.1:${toString forge.listenPort}";
        inherit tokenFile;
        topic = bot;
        userAllowlist = [ forge.admin.username ];
      };
    };
  };

  systemd.services = {
    forge-ci-token = {
      description = "Mint the Forgejo token of the CI service account";
      wantedBy = [ "multi-user.target" ];
      after = [ "forgejo-repositories.service" ];
      requires = [ "forgejo-repositories.service" ];

      environment = {
        USER = forgejo.user;
        HOME = forgejo.stateDir;
        FORGEJO_WORK_DIR = forgejo.stateDir;
        FORGEJO_CUSTOM = forgejo.customDir;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = forgejo.user;
        Group = forgejo.group;
        WorkingDirectory = forgejo.stateDir;
        StateDirectory = baseNameOf stateDir;
        StateDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = lib.getExe mintToken;
      };
    };

    nixbot = {
      after = [ "forge-ci-token.service" ];
      requires = [ "forge-ci-token.service" ];
    };
  };

  environment.persistence = lib.mkIf impermanenceEnabled {
    "/persist/system".directories = [
      {
        directory = stateDir;
        inherit (forgejo) user group;
        mode = "0700";
      }
      {
        directory = "/var/lib/nixbot";
        user = "nixbot";
        group = "nixbot";
        mode = "0700";
      }
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0750";
      }
    ];
  };
}
