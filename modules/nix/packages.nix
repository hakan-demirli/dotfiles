{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (inputs.self.lib)
        codegen
        intent
        kexecRootKeys
        ;

      passwordBootstrapPubFile = inputs.self + "/secrets/bootstrap/password.age.pub";
      tailscaleBootstrapPubFile = inputs.self + "/secrets/bootstrap/tailscale.age.pub";
      passwordBootstrapIdentityFile = inputs.self + "/secrets/bootstrap/password.age.key.enc";
      tailscaleBootstrapIdentityFile = inputs.self + "/secrets/bootstrap/tailscale.age.key.enc";
      passwordBootstrapRecipient = lib.removeSuffix "\n" (builtins.readFile passwordBootstrapPubFile);
      tailscaleBootstrapRecipient = lib.removeSuffix "\n" (builtins.readFile tailscaleBootstrapPubFile);
      sendToLaptop = pkgs.callPackage ../home/common/pkgs/nix/send-to-laptop.nix { };
      deployHomeSecrets = pkgs.writeShellApplication {
        name = "deploy-home-secrets";
        runtimeInputs = [
          inputs.home-manager.packages.${system}.default
          pkgs.age
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.nixVersions.latest
        ];
        text = builtins.readFile ./pkgs/bin/deploy-home-secrets.sh;
      };
      deploySystemSecrets = pkgs.writeShellApplication {
        name = "deploy-system-secrets";
        runtimeInputs = [
          pkgs.age
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.nixVersions.latest
          pkgs.nixos-rebuild
          pkgs.util-linux
        ];
        text = builtins.readFile ./pkgs/bin/deploy-system-secrets.sh;
      };
      intentReport =
        pkgs.runCommand "intent-report"
          {
            violationsJson = builtins.toJSON intent.intentViolations;
            passAsFile = [ "violationsJson" ];
          }
          ''
            mkdir -p $out
            cp "$violationsJsonPath" $out/intent-violations.json
            numErrors=$(${pkgs.jq}/bin/jq '[ .[] | select(.severity == "error") ] | length' "$violationsJsonPath")
            numWarns=$(${pkgs.jq}/bin/jq '[ .[] | select(.severity == "warn") ] | length' "$violationsJsonPath")
            {
              echo "intent-check report"
              echo "==================="
              echo "errors:   $numErrors"
              echo "warnings: $numWarns"
              echo ""
              ${pkgs.jq}/bin/jq -r '.[] | "[\(.severity)] [\(.kind)] \(.message)"' "$violationsJsonPath"
            } > $out/intent-report.txt
            if [ "$numErrors" -gt 0 ]; then
              echo "intent-check FAILED: $numErrors errors" >&2
              cat $out/intent-report.txt >&2
              exit 1
            fi
          '';
      mkBootstrapDeploy =
        {
          name,
          passwordIdentityFile,
          passwordRecipient,
          tailscaleIdentityFile,
          tailscaleRecipient,
          requireRoot ? true,
          requireMountpoint ? true,
          runtimeRoot ? "/run",
        }:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [
            pkgs.age
            pkgs.coreutils
            pkgs.util-linux
          ];
          text = ''
            ${lib.optionalString requireRoot ''
              if (( EUID != 0 )); then
                echo "bootstrap-deploy must run as root" >&2
                exit 1
              fi
            ''}
            if (( $# < 1 || $# > 2 )); then
              echo "usage: bootstrap-deploy TARGET_ROOT [--with-tailscale]" >&2
              exit 2
            fi

            target_root=$1
            with_tailscale=false
            if (( $# == 2 )); then
              if [[ $2 != --with-tailscale ]]; then
                echo "usage: bootstrap-deploy TARGET_ROOT [--with-tailscale]" >&2
                exit 2
              fi
              with_tailscale=true
            fi

            if [[ "$target_root" == / ]]; then
              persist=/persist
            else
              persist="''${target_root%/}/persist"
            fi

            ${lib.optionalString requireMountpoint ''
              if ! mountpoint -q "$persist"; then
                echo "refusing bootstrap deployment: $persist is not a mount point" >&2
                exit 1
              fi
            ''}

            umask 077
            staging="$(mktemp -d ${lib.escapeShellArg "${runtimeRoot}/bootstrap-deploy.XXXXXX"})"
            trap 'rm -rf "$staging"' EXIT

            decrypt_identity() {
              local encrypted=$1
              local expected=$2
              local label=$3
              local output=$4
              local actual

              if [[ ! -s "$encrypted" ]]; then
                echo "$label encrypted age identity is missing: $encrypted" >&2
                exit 1
              fi
              if ! age --decrypt --output "$output" "$encrypted"; then
                echo "$label age identity could not be decrypted" >&2
                exit 1
              fi
              if [[ ! -s "$output" ]]; then
                echo "$label decrypted age identity is empty" >&2
                exit 1
              fi
              chmod 0600 "$output"
              if ! actual="$(age-keygen -y "$output")"; then
                echo "$label decrypted age identity is invalid" >&2
                exit 1
              fi
              if [[ "$actual" != "$expected" ]]; then
                echo "$label age identity has the wrong recipient" >&2
                exit 1
              fi
            }

            password_staged="$staging/bootstrap-password.key"
            tailscale_staged="$staging/bootstrap-tailscale.key"
            decrypt_identity \
              ${lib.escapeShellArg (toString passwordIdentityFile)} \
              ${lib.escapeShellArg passwordRecipient} \
              password-bootstrap \
              "$password_staged"
            if [[ $with_tailscale == true ]]; then
              decrypt_identity \
                ${lib.escapeShellArg (toString tailscaleIdentityFile)} \
                ${lib.escapeShellArg tailscaleRecipient} \
                tailscale-bootstrap \
                "$tailscale_staged"
            fi

            destination="$persist/system/var/lib/sops-nix"
            install -d -m 0700 "$destination"
            install -m 0600 "$password_staged" "$destination/bootstrap-password.key"
            echo "deployed mandatory password bootstrap identity"

            if [[ $with_tailscale == true ]]; then
              install -m 0600 "$tailscale_staged" "$destination/bootstrap-tailscale.key"
              echo "deployed optional Tailscale bootstrap identity"
            else
              echo "warning: optional Tailscale bootstrap identity was not requested" >&2
            fi

            sync "$destination"
          '';
        };
      bootstrapDeploy = mkBootstrapDeploy {
        name = "bootstrap-deploy";
        passwordIdentityFile = passwordBootstrapIdentityFile;
        passwordRecipient = passwordBootstrapRecipient;
        tailscaleIdentityFile = tailscaleBootstrapIdentityFile;
        tailscaleRecipient = tailscaleBootstrapRecipient;
      };
      testIdentityFile = inputs.self + /modules/nix/checks/fixtures/bootstrap-age.key.enc;
      testRecipient = "age1yt3tfqlfrwdwx0z0ynwplcr6qxcxfaqycuprpmy89nr83ltx74tqdpszlw";
      testBootstrapDeploy = mkBootstrapDeploy {
        name = "bootstrap-deploy-test";
        passwordIdentityFile = testIdentityFile;
        passwordRecipient = testRecipient;
        tailscaleIdentityFile = testIdentityFile;
        tailscaleRecipient = testRecipient;
        requireRoot = false;
        requireMountpoint = false;
        runtimeRoot = "/tmp";
      };
      wrongRecipientBootstrapDeploy = mkBootstrapDeploy {
        name = "bootstrap-deploy-wrong-recipient";
        passwordIdentityFile = testIdentityFile;
        passwordRecipient = tailscaleBootstrapRecipient;
        tailscaleIdentityFile = testIdentityFile;
        tailscaleRecipient = testRecipient;
        requireRoot = false;
        requireMountpoint = false;
        runtimeRoot = "/tmp";
      };
      mountGuardBootstrapDeploy = mkBootstrapDeploy {
        name = "bootstrap-deploy-mount-guard";
        passwordIdentityFile = testIdentityFile;
        passwordRecipient = testRecipient;
        tailscaleIdentityFile = testIdentityFile;
        tailscaleRecipient = testRecipient;
        requireRoot = false;
        runtimeRoot = "/tmp";
      };
      bootstrapDeployCheck =
        pkgs.runCommand "bootstrap-deploy-test"
          {
            nativeBuildInputs = [ pkgs.expect ];
          }
          ''
            run_with_passphrases() {
              local executable=$1
              local target=$2
              local prompts=$3
              local extra_arg=''${4:-}

              expect -f - "$executable" "$target" "$prompts" "$extra_arg" <<'EOF'
            set executable [lindex $argv 0]
            set target [lindex $argv 1]
            set prompts [lindex $argv 2]
            set extra_arg [lindex $argv 3]
            set timeout 20
            if {$extra_arg eq ""} {
              spawn $executable $target
            } else {
              spawn $executable $target $extra_arg
            }
            for {set index 0} {$index < $prompts} {incr index} {
              expect {
                -re "Enter passphrase.*:" { send -- "bootstrap-test-passphrase\r" }
                timeout { exit 124 }
                eof { exit 125 }
              }
            }
            expect eof
            set result [wait]
            exit [lindex $result 3]
            EOF
            }

            target="$TMPDIR/password-only"
            mkdir -p "$target/persist"
            run_with_passphrases \
              ${testBootstrapDeploy}/bin/bootstrap-deploy-test \
              "$target" \
              1
            test -s "$target/persist/system/var/lib/sops-nix/bootstrap-password.key"
            test "$(stat -c %a "$target/persist/system/var/lib/sops-nix")" = 700
            test "$(stat -c %a "$target/persist/system/var/lib/sops-nix/bootstrap-password.key")" = 600
            test ! -e "$target/persist/system/var/lib/sops-nix/bootstrap-tailscale.key"

            target="$TMPDIR/with-tailscale"
            mkdir -p "$target/persist"
            run_with_passphrases \
              ${testBootstrapDeploy}/bin/bootstrap-deploy-test \
              "$target" \
              2 \
              --with-tailscale
            test -s "$target/persist/system/var/lib/sops-nix/bootstrap-password.key"
            test -s "$target/persist/system/var/lib/sops-nix/bootstrap-tailscale.key"

            target="$TMPDIR/wrong-recipient"
            mkdir -p "$target/persist"
            if run_with_passphrases \
              ${wrongRecipientBootstrapDeploy}/bin/bootstrap-deploy-wrong-recipient \
              "$target" \
              1; then
              echo "bootstrap-deploy accepted an identity with the wrong recipient" >&2
              exit 1
            fi
            test ! -e "$target/persist/system/var/lib/sops-nix/bootstrap-password.key"

            target="$TMPDIR/not-mounted"
            mkdir -p "$target/persist"
            if ${mountGuardBootstrapDeploy}/bin/bootstrap-deploy-mount-guard "$target"; then
              echo "bootstrap-deploy accepted an unmounted persistence directory" >&2
              exit 1
            fi

            touch "$out"
          '';
    in
    {
      packages = {
        default = codegen.sopsYaml { inherit pkgs; };
        sops-yaml = codegen.sopsYaml { inherit pkgs; };
        matchbox = codegen.matchbox { inherit pkgs; };
        kea = codegen.kea { inherit pkgs; };
        headscale-acl = codegen.headscaleAcl { inherit pkgs; };

        intent-report = intentReport;
        bootstrap-deploy = bootstrapDeploy;
        deploy-home-secrets = deployHomeSecrets;
        deploy-system-secrets = deploySystemSecrets;
        send-to-laptop = sendToLaptop;

        inventory-dump = pkgs.writeShellApplication {
          name = "inventory-dump";
          runtimeInputs = [
            pkgs.jq
            pkgs.nix
          ];
          text = ''nix eval --json --no-warn-dirty "${inputs.self}#lib.inventory" | jq .'';
        };
      }
      // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        kexec =
          inputs.infra-lib.lib.mkKexecBundle {
            inherit inputs system;
            rootKeys = kexecRootKeys;
          }
          // {
            meta.description = "Self-extracting kexec bundle: bash <bundle> on a foreign distro to take over the box.";
          };

      };

      checks = lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        test-bootstrap-deploy = bootstrapDeployCheck;
      };
    };
}
