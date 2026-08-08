{
  pkgs,
  self,
  inputs,
}:
let
  testKeys = import (inputs.infra-lib + "/modules/nix/checks/lib/fixtures/test-ed25519-keys.nix") {
    inherit pkgs;
  };
  passwordFixture = self + /modules/nix/checks/fixtures/bootstrap-password.yaml;
  ageIdentity = inputs.sops-nix + "/pkgs/sops-install-secrets/test-assets/age-keys.txt";

  testCluster.users."user-test".system_account.username = "test-user";
  mkHost = hostId: {
    id = hostId;
    ownership.owner = "user-test";
    impermanence.enable = false;
  };
  tailscaleUseAuthKeyOption =
    { lib, ... }:
    {
      options.services.tailscale.useAuthKey = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  mkNode =
    {
      hostId,
      passwordAccount,
      rootPasswordSudo,
    }:
    { lib, ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        inputs.impermanence.nixosModules.impermanence
        tailscaleUseAuthKeyOption
        (self + /modules/services/sops.nix)
      ];

      _module.args = {
        inherit inputs;
        host = mkHost hostId;
        cluster = testCluster;
      };

      services = {
        sops.bootstrap = {
          inherit passwordAccount;
          passwordKeyFile = toString ageIdentity;
          passwordSopsFile = passwordFixture;
          tailscaleKeyFile = "/missing/tailscale-bootstrap.key";
        };
        openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        tailscale.enable = true;
      };

      users.users = {
        "test-user" = {
          isNormalUser = true;
          uid = 1000;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ testKeys.admin.publicKey ];
        };
        root = {
          openssh.authorizedKeys.keys = [ testKeys.admin.publicKey ];
        }
        // lib.optionalAttrs (passwordAccount == "owner") {
          hashedPasswordFile = lib.mkForce null;
        };
      };

      security.sudo = {
        wheelNeedsPassword = true;
        extraConfig = lib.optionalString rootPasswordSudo ''
          Defaults:%wheel rootpw
        '';
      };

      networking = {
        firewall.enable = false;
        networkmanager.enable = false;
      };

      environment.systemPackages = [
        pkgs.openssh
        pkgs.sshpass
      ];

      virtualisation = {
        memorySize = 1024;
        cores = 2;
      };

      system.stateVersion = "26.11";
    };
in
pkgs.testers.runNixOSTest {
  name = "bootstrap-authentication";

  nodes = {
    laptop = mkNode {
      hostId = "laptop-test";
      passwordAccount = "owner";
      rootPasswordSudo = false;
    };
    server = mkNode {
      hostId = "server-test";
      passwordAccount = "root";
      rootPasswordSudo = true;
    };
  };

  testScript = ''
    import time

    started = time.time()

    def stage(message):
        print(f"\n========== [t+{time.time() - started:6.1f}s] {message} ==========")

    def shadow_hash(machine, user):
        return machine.succeed(f"getent shadow {user} | cut -d: -f2").strip()

    def expect_failure(machine, command, message):
        status, output = machine.execute(command, timeout=30)
        assert status != 0, f"{message}: unexpectedly succeeded. output={output!r}"

    def sudo_with_password(machine, password, should_succeed, label):
        command = (
            f"printf '%s\\n' '{password}' "
            "| runuser -u test-user -- sudo -S -k true"
        )
        status, output = machine.execute(command, timeout=30)
        assert (status == 0) == should_succeed, (
            f"{label}: status={status}, expected_success={should_succeed}, output={output!r}"
        )

    stage("boot both authentication policies")
    start_all()
    for machine in (laptop, server):
        machine.wait_for_unit("multi-user.target", timeout=120)
        machine.wait_for_unit("sshd.service", timeout=60)
        machine.wait_for_open_port(22, timeout=60)

    stage("password hashes target opposite accounts")
    assert shadow_hash(laptop, "test-user").startswith("$6$")
    assert shadow_hash(laptop, "root") == "!"
    assert shadow_hash(server, "test-user") == "!"
    assert shadow_hash(server, "root").startswith("$6$")

    stage("install public test credential")
    for machine in (laptop, server):
        machine.succeed("install -m 0600 ${testKeys.admin.privateKey} /tmp/test-identity")

    ssh_key_options = (
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o BatchMode=yes -o ConnectTimeout=10"
    )
    ssh_password_options = (
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o PreferredAuthentications=password -o PubkeyAuthentication=no "
        "-o NumberOfPasswordPrompts=1 -o ConnectTimeout=10"
    )

    stage("normal users log in with keys, including locked server user")
    for machine in (laptop, server):
        machine.succeed(
            f"ssh {ssh_key_options} -i /tmp/test-identity test-user@localhost true"
        )

    stage("direct root SSH is denied despite an authorized key")
    for machine in (laptop, server):
        expect_failure(
            machine,
            f"ssh {ssh_key_options} -i /tmp/test-identity root@localhost true",
            "root SSH",
        )

    stage("password SSH is denied even for accounts with valid passwords")
    expect_failure(
        laptop,
        f"sshpass -p laptop-password ssh {ssh_password_options} test-user@localhost true",
        "laptop user password SSH",
    )
    expect_failure(
        server,
        f"sshpass -p server-root-password ssh {ssh_password_options} root@localhost true",
        "server root password SSH",
    )

    stage("laptop sudo authenticates with owner password")
    sudo_with_password(laptop, "laptop-password", True, "laptop owner password")
    sudo_with_password(laptop, "server-root-password", False, "laptop root password")

    stage("server sudo authenticates with root password")
    sudo_with_password(server, "server-root-password", True, "server root password")
    sudo_with_password(server, "laptop-password", False, "server user password")

    stage("non-interactive sudo remains denied")
    for machine in (laptop, server):
        expect_failure(
            machine,
            "runuser -u test-user -- sudo -k -n true",
            "passwordless sudo",
        )

    stage("generated policy is explicit")
    assert "Defaults:%wheel rootpw" not in laptop.succeed("cat /etc/sudoers")
    assert "Defaults:%wheel rootpw" in server.succeed("cat /etc/sudoers")
    for machine in (laptop, server):
        sshd = machine.succeed("cat /etc/ssh/sshd_config")
        assert "PasswordAuthentication no" in sshd
        assert "KbdInteractiveAuthentication no" in sshd
        assert "PermitRootLogin no" in sshd

    print("BOOTSTRAP AUTHENTICATION POLICY VERIFIED")
  '';
}
