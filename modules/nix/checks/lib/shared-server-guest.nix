{
  pkgs,
  self,
  inputs,
}:
let
  testlib = import (inputs.infra-lib + "/modules/nix/checks/lib/lib.nix") { inherit pkgs; };
  generatedPolicy = "${self.packages.${pkgs.system}.headscale-acl}/policy.hujson";
  mkServer =
    { ... }:
    {
      imports = [ (testlib.mkTailscaleNode { }) ];
      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };
      virtualisation.memorySize = 768;
    };
in
pkgs.testers.runNixOSTest {
  name = "shared-server-guest";

  nodes = {
    headscale = testlib.mkHeadscaleNode { aclFile = generatedPolicy; };

    shared_server =
      { ... }:
      {
        imports = [ mkServer ];
        users.users.guest0 = {
          isNormalUser = true;
          uid = 1001;
          createHome = true;
        };
        services.nginx = {
          enable = true;
          virtualHosts."shared-server-1".locations."/".return = "200 ok";
        };
      };

    other_server = mkServer;

    guest_client =
      { pkgs, ... }:
      {
        imports = [ (testlib.mkTailscaleNode { }) ];
        environment.systemPackages = [ pkgs.netcat-openbsd ];
        virtualisation.memorySize = 768;
      };

    guest_second =
      { pkgs, ... }:
      {
        imports = [ (testlib.mkTailscaleNode { }) ];
        environment.systemPackages = [ pkgs.netcat-openbsd ];
        virtualisation.memorySize = 768;
      };
  };

  testScript = ''
    start_all()
    ${testlib.snippets.bootHeadscale}
    ${testlib.snippets.helperDefs}

    headscale.succeed("headscale users create user-0")
    headscale.succeed("headscale users create guest-0")
    headscale.succeed("headscale policy check --file ${generatedPolicy}")

    owner_id = get_user_id("user-0")
    guest_id = get_user_id("guest-0")
    shared_key = headscale.succeed(
        f"headscale preauthkeys create --user {owner_id} --expiration 24h "
        "--tags tag:cluster-shared-server-1,tag:cluster-shared-server-1-login,tag:metrics"
    ).strip()
    other_key = headscale.succeed(
        f"headscale preauthkeys create --user {owner_id} --expiration 24h "
        "--tags tag:cluster-user-0-fleet"
    ).strip()
    guest_key = headscale.succeed(
        f"headscale preauthkeys create --user {guest_id} --reusable --expiration 720h"
    ).strip()

    for node in [shared_server, other_server, guest_client, guest_second]:
        node.wait_for_unit("tailscaled.service")

    for node, hostname, key in [
        (shared_server, "shared-server-1", shared_key),
        (other_server, "other-server", other_key),
        (guest_client, "guest-client", guest_key),
        (guest_second, "guest-second", guest_key),
    ]:
        node.succeed(
            f"tailscale up --authkey={key} --hostname={hostname} "
            "--login-server=https://headscale --timeout=60s"
        )
        headscale.wait_until_succeeds(f"headscale nodes list | grep -F {hostname}")

    shared_server.wait_for_unit("sshd.service")
    shared_server.wait_for_open_port(80)
    other_server.wait_for_unit("sshd.service")
    shared_ip = get_ts_ip(shared_server)
    other_ip = get_ts_ip(other_server)

    guest_client.succeed("ssh-keygen -q -t ed25519 -N \"\" -f /tmp/guest-key")
    pubkey = guest_client.succeed("cat /tmp/guest-key.pub").strip()
    shared_server.succeed("install -d -o guest0 -g users -m 0700 /home/guest0/.ssh")
    shared_server.succeed(
        f"printf '%s\\n' '{pubkey}' > /home/guest0/.ssh/authorized_keys && "
        "chown guest0:users /home/guest0/.ssh/authorized_keys && "
        "chmod 0600 /home/guest0/.ssh/authorized_keys"
    )

    guest_client.wait_until_succeeds(
        f"ssh -i /tmp/guest-key -o IdentitiesOnly=yes -o BatchMode=yes "
        f"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        f"-o ConnectTimeout=5 guest0@{shared_ip} id -un | grep -Fx guest0",
        timeout=60,
    )
    guest_client.succeed(f"nc -z -w 3 {shared_ip} 80")
    guest_client.fail(f"nc -z -w 3 {other_ip} 22")
    guest_second.wait_until_succeeds(f"nc -z -w 3 {shared_ip} 22", timeout=60)

    print("NUMBERED GUEST SSH AND ACL VERIFIED")
  '';
}
