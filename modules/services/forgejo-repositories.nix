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

  state = pkgs.writeText "forgejo-repositories.json" (
    builtins.toJSON {
      users = lib.mapAttrsToList (name: user: {
        inherit name;
        inherit (user) email;
      }) cfg.users;
      repositories = lib.mapAttrsToList (name: repo: {
        inherit name;
        inherit (repo)
          private
          defaultBranch
          topics
          settings
          ;
        collaborators = lib.mapAttrsToList (user: permission: {
          inherit user permission;
        }) repo.collaborators;
        branchProtections = lib.mapAttrsToList (
          rule: protection: protection // { rule_name = rule; }
        ) repo.branchProtections;
      }) cfg.repositories;
      inherit (cfg) sshKeys;
    }
  );

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

      found() {
        local status
        status="$(curl -sS -o /dev/null -w '%{http_code}' --netrc-file "$netrc" "$api$1")"
        case $status in
          200) return 0 ;;
          404) return 1 ;;
          *)
            echo "fatal: GET $1 returned HTTP $status" >&2
            exit 1
            ;;
        esac
      }

      for _ in $(seq 60); do
        curl -fsS -o /dev/null "$api/version" && break
        sleep 2
      done

      jq -c '.users[]' ${state} | while IFS= read -r user; do
        name="$(jq -r .name <<< "$user")"
        found "/users/$name" && continue
        echo "forgejo-repositories: creating service account $name"
        jq -nc --argjson user "$user" --arg password "$(head -c 48 /dev/urandom | base64 -w0)" \
          '{username: $user.name, email: $user.email, password: $password, must_change_password: false, visibility: "private", source_id: 0, login_name: $user.name}' \
          | call POST /admin/users --data @- -o /dev/null
      done

      jq -c '.repositories[]' ${state} | while IFS= read -r repo; do
        name="$(jq -r .name <<< "$repo")"
        path="/repos/$owner/$name"

        if ! found "$path"; then
          echo "forgejo-repositories: creating $owner/$name"
          jq -nc --argjson repo "$repo" \
            '{name: $repo.name, private: $repo.private, default_branch: ($repo.defaultBranch // "main"), auto_init: false}' \
            | call POST /user/repos --data @- -o /dev/null
        fi

        default_branch="$(jq -r '.defaultBranch // empty' <<< "$repo")"
        if [[ -n $default_branch ]] && ! found "$path/branches/$default_branch"; then
          echo "forgejo-repositories: $owner/$name has no branch $default_branch yet; keeping its default branch"
          default_branch=""
        fi
        jq -c --arg branch "$default_branch" \
          '.settings + {private} + (if $branch == "" then {} else {default_branch: $branch} end)' <<< "$repo" \
          | call PATCH "$path" --data @- -o /dev/null

        jq -c '{topics}' <<< "$repo" | call PUT "$path/topics" --data @- -o /dev/null

        declared="$(jq -c '[.collaborators[].user]' <<< "$repo")"
        call GET "$path/collaborators?limit=50" | jq -r --argjson declared "$declared" \
          '.[].login | select(. as $u | $declared | index($u) | not)' | while IFS= read -r stray; do
          echo "forgejo-repositories: removing undeclared collaborator $stray from $owner/$name"
          call DELETE "$path/collaborators/$stray" -o /dev/null
        done
        jq -c '.collaborators[]' <<< "$repo" | while IFS= read -r collaborator; do
          jq -c '{permission}' <<< "$collaborator" \
            | call PUT "$path/collaborators/$(jq -r .user <<< "$collaborator")" --data @- -o /dev/null
        done

        declared="$(jq -c '[.branchProtections[].rule_name]' <<< "$repo")"
        call GET "$path/branch_protections" | jq -r --argjson declared "$declared" \
          '.[].rule_name | select(. as $r | $declared | index($r) | not)' | while IFS= read -r stray; do
          echo "forgejo-repositories: removing undeclared branch protection $stray from $owner/$name"
          call DELETE "$path/branch_protections/$stray" -o /dev/null
        done
        jq -c '.branchProtections[]' <<< "$repo" | while IFS= read -r protection; do
          rule="$(jq -r .rule_name <<< "$protection")"
          if found "$path/branch_protections/$rule"; then
            jq -c 'del(.rule_name)' <<< "$protection" \
              | call PATCH "$path/branch_protections/$rule" --data @- -o /dev/null
          else
            echo "forgejo-repositories: protecting $rule on $owner/$name"
            call POST "$path/branch_protections" --data "$protection" -o /dev/null
          fi
        done
      done

      declared="$(jq -c '.sshKeys | map(split(" ")[0:2] | join(" "))' ${state})"
      present="$(call GET '/user/keys?limit=50')"

      jq -r --argjson declared "$declared" \
        '.[] | select((.key | split(" ")[0:2] | join(" ")) as $k | $declared | index($k) | not) | .id' \
        <<< "$present" | while IFS= read -r id; do
        echo "forgejo-repositories: removing undeclared SSH key $id"
        call DELETE "/user/keys/$id" -o /dev/null
      done

      jq -c '.sshKeys[]' ${state} | while IFS= read -r key; do
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
    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.email = lib.mkOption {
            type = lib.types.str;
            description = "Address recorded for the service account.";
          };
        }
      );
      default = { };
      description = "Service accounts with an unknown random password, keyed by login. Tokens are minted on the host.";
    };

    repositories = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            private = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether only the administrator and collaborators may read the repository.";
            };

            defaultBranch = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Default branch, applied once the branch exists.";
            };

            topics = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };

            collaborators = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.enum [
                  "read"
                  "write"
                  "admin"
                ]
              );
              default = { };
              description = "Exact set of collaborators and their permission.";
            };

            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              description = "Fields of Forgejo's EditRepoOption, such as the allowed merge styles.";
            };

            branchProtections = lib.mkOption {
              type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
              default = { };
              description = "Exact set of branch protection rules, keyed by rule name, valued by Forgejo's CreateBranchProtectionOption fields.";
            };
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
          lib.attrNames cfg.repositories ++ lib.attrNames cfg.users
        );
        message = "services.forgejo-repositories names must be plain Forgejo repository and user names.";
      }
      {
        assertion = lib.all (repo: lib.all (user: cfg.users ? ${user}) (lib.attrNames repo.collaborators)) (
          lib.attrValues cfg.repositories
        );
        message = "services.forgejo-repositories collaborators must be declared service accounts.";
      }
    ];

    systemd.services.forgejo-repositories = {
      description = "Provision the declared Forgejo repositories, service accounts and administrator SSH keys";
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
