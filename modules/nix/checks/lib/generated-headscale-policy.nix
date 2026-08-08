{
  pkgs,
  self,
  inputs,
}:
let
  inherit (pkgs) lib;
  testlib = import (inputs.infra-lib + "/modules/nix/checks/lib/lib.nix") { inherit pkgs; };
  aclFile = "${self.packages.${pkgs.system}.headscale-acl}/policy.hujson";
  headscaleUsers = lib.unique (
    lib.filter (username: username != null) (
      lib.mapAttrsToList (_: user: user.headscale_user or null) self.lib.inventory.users
    )
  );
  createUsers = lib.concatMapStringsSep "\n    " (
    username: ''headscale.succeed("headscale users create ${lib.escapeShellArg username}")''
  ) headscaleUsers;
in
pkgs.testers.runNixOSTest {
  name = "generated-headscale-policy";

  nodes.headscale = testlib.mkHeadscaleNode { inherit aclFile; };

  testScript = ''
    start_all()
    ${testlib.snippets.bootHeadscale}

    ${createUsers}
    headscale.succeed("headscale policy check --file ${aclFile}")

    print("PRODUCTION-GENERATED HEADSCALE POLICY VERIFIED")
  '';
}
