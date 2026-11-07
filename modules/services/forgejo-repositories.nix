{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.forgejo-repositories;
  forge = config.services.cluster-forgejo;
  forgejo = config.services.forgejo;

  passwordPath =
    if forge.admin.password.source == "sops" then
      config.sops.secrets.${forge.admin.password.sopsKeyName}.path
    else
      forge.admin.password.hostLocalPath;

  repositories = pkgs.writeText "forgejo-repositories.json" (
    builtins.toJSON (
      lib.mapAttrsToList (name: repo: {
        inherit name;
        inherit (repo) private;
      }) cfg.repositories
    )
  );

  sshKeys = pkgs.writeText "forgejo-ssh-keys.json" (builtins.toJSON cfg.sshKeys);

  provision = pkgs.writeShellApplication {
    name = "forgejo-repositories";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      api=${lib.escapeShellArg "http://127.0.0.1:${toString forge.listenPort}/api/v1"}
      owner=${lib.escapeShellArg forge.admin.username}
      netrc="$RUNTIME_DIRECTORY/netrc"

      password="$(<"$CREDENTIALS_DIRECTORY/admin-password")"
      printf 'machine 127.0.0.1 login %s password %s\n' "$owner" "$password" > "$netrc"

      call() {
        local method=$1 path=$2
        shift 2
        curl -fsS --netrc-file "$netrc" -X "$method" -H 'Content-Type: application/json' "$@" "$api$path"
      }

      for _ in $(seq 60); do
        curl -fsS -o /dev/null "$api/version" && break
        sleep 2
      done

      jq -c '.[]' ${repositories} | while IFS= read -r repo; do
        name="$(jq -r .name <<< "$repo")"
        private="$(jq -r .private <<< "$repo")"
        status="$(curl -sS -o /dev/null -w '%{http_code}' --netrc-file "$netrc" "$api/repos/$owner/$name")"
        case $status in
          200)
            jq -nc --argjson private "$private" '{private: $private}' \
              | call PATCH "/repos/$owner/$name" --data @- -o /dev/null
            ;;
          404)
            echo "forgejo-repositories: creating $owner/$name"
            jq -nc --arg name "$name" --argjson private "$private" \
              '{name: $name, private: $private, default_branch: "main", auto_init: false}' \
              | call POST /user/repos --data @- -o /dev/null
            ;;
          *)
            echo "fatal: looking up $owner/$name returned HTTP $status" >&2
            exit 1
            ;;
        esac
      done

      declared="$(jq -c 'map(split(" ")[0:2] | join(" "))' ${sshKeys})"
      present="$(call GET '/user/keys?limit=50')"

      jq -r --argjson declared "$declared" \
        '.[] | select((.key | split(" ")[0:2] | join(" ")) as $k | $declared | index($k) | not) | .id' \
        <<< "$present" | while IFS= read -r id; do
        echo "forgejo-repositories: removing undeclared SSH key $id"
        call DELETE "/user/keys/$id" -o /dev/null
      done

      jq -c '.[]' ${sshKeys} | while IFS= read -r key; do
        material="$(jq -r 'split(" ")[0:2] | join(" ")' <<< "$key")"
        if jq -e --arg k "$material" 'any(.[]; (.key | split(" ")[0:2] | join(" ")) == $k)' <<< "$present" >/dev/null; then
          continue
        fi
        echo "forgejo-repositories: adding SSH key $(jq -r 'split(" ")[2] // "unnamed"' <<< "$key")"
        jq -nc --argjson key "$key" '{key: $key, title: ($key | split(" ")[2] // ($key | split(" ")[1][-12:])), read_only: false}' \
          | call POST /user/keys --data @- -o /dev/null
      done
    '';
  };
in
{
  options.services.forgejo-repositories = {
    repositories = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.private = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether only the administrator may read the repository.";
          };
        }
      );
      default = { };
      description = "Repositories owned by the Forgejo administrator, keyed by repository name.";
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Exact set of SSH public keys that may push as the Forgejo administrator.";
    };
  };

  config = lib.mkIf (cfg.repositories != { } || cfg.sshKeys != [ ]) {
    assertions = [
      {
        assertion = lib.all (name: builtins.match "[A-Za-z0-9_.-]+" name != null) (
          lib.attrNames cfg.repositories
        );
        message = "services.forgejo-repositories.repositories names must be plain Forgejo repository names.";
      }
    ];

    systemd.services.forgejo-repositories = {
      description = "Provision the declared Forgejo repositories and administrator SSH keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "forgejo-admin.service" ];
      requires = [ "forgejo-admin.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = forgejo.user;
        Group = forgejo.group;
        LoadCredential = [ "admin-password:${passwordPath}" ];
        RuntimeDirectory = "forgejo-repositories";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = lib.getExe provision;
      };
    };
  };
}
