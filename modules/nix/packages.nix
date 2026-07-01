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

      bootstrapPubFile = inputs.self + "/secrets/age-bootstrap.key.pub";
      bootstrapAge =
        if builtins.pathExists bootstrapPubFile then
          lib.filter (s: lib.hasPrefix "age1" s) (lib.splitString "\n" (builtins.readFile bootstrapPubFile))
        else
          [ ];
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
    in
    {
      packages = {
        default = codegen.sopsYaml { inherit pkgs bootstrapAge; };
        sops-yaml = codegen.sopsYaml { inherit pkgs bootstrapAge; };
        matchbox = codegen.matchbox { inherit pkgs; };
        kea = codegen.kea { inherit pkgs; };
        headscale-acl = codegen.headscaleAcl { inherit pkgs; };

        intent-report = intentReport;

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
    };
}
