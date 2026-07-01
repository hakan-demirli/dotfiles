{ pkgs, self }:
let
  intent = self.lib.intent;
in
pkgs.runCommand "intent-check"
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
  ''
