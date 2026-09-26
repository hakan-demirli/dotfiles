{
  pkgs,
  self,
  inputs,
}:
let
  inherit (pkgs) lib;
  testlib = import (inputs.infra-lib + "/modules/nix/checks/lib/lib.nix") { inherit pkgs; };
  aclFile = "${self.packages.${pkgs.system}.headscale-acl}/policy.hujson";
  guestPrincipals = (import ../../../../inventory/tailnet-acl.nix).groups."group:shared-server-users";
  headscaleUsers = lib.unique (
    lib.filter (username: username != null) (
      lib.mapAttrsToList (_: user: user.headscale_user or null) self.lib.inventory.users
    )
    ++ map (lib.removeSuffix "@") guestPrincipals
  );
  createUsers = lib.concatMapStringsSep "\n" (
    username: ''headscale.succeed("headscale users create ${lib.escapeShellArg username}")''
  ) headscaleUsers;
in
pkgs.testers.runNixOSTest {
  name = "generated-headscale-policy";

  nodes.headscale = testlib.mkHeadscaleNode { inherit aclFile; };

  testScript = ''
    start_all()
    ${testlib.snippets.bootHeadscale}

    import json
    from pathlib import Path

    policy = json.loads(Path("${aclFile}").read_text())
    assert "guest-0@" in policy["groups"]["group:shared-server-users"]
    assert policy["tagOwners"]["tag:shared-server-login"] == ["group:admin"]
    assert [
        rule for rule in policy["acls"]
        if "group:shared-server-users" in rule["src"]
    ] == [{
        "action": "accept",
        "src": ["group:shared-server-users"],
        "dst": ["tag:shared-server-login:22"],
    }]

    ${createUsers}
    headscale.succeed("headscale policy check --file ${aclFile}")

    print("PRODUCTION-GENERATED HEADSCALE POLICY VERIFIED")
  '';
}
