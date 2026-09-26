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

  testCluster = {
    users = {
      "user-test".system_account.username = "test-user";
      "guest-test".system_account = {
        username = "guest-user";
        groups = [ ];
      };
    };
    unixAccessTiers.admin = {
      groups = [ "wheel" ];
      root_ssh = false;
      sudo.extra_rule = null;
      ssh.allowed = true;
    };
    usersOnHost."shared-test" = [
      {
        user = "user-test";
        unix_tier = "admin";
      }
      {
        user = "guest-test";
        unix_tier = "admin";
      }
    ];
  };
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
      guests ? { },
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
      }
      // guests;

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
  globalTimeout = 300;

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
    shared = mkNode {
      hostId = "shared-test";
      passwordAccount = "owner";
      rootPasswordSudo = false;
      guests."guest-user" = {
        isNormalUser = true;
        uid = 1001;
        extraGroups = [ "wheel" ];
      };
    };
  };

  testScript = ''
    import datetime as dt
    import time

    BOOT_TIMEOUT = dt.timedelta(minutes=2)
    COMMAND_TIMEOUT = dt.timedelta(seconds=30)
    SSH_DENIED = (255, "Permission denied (publickey)")
    SUDO_PASSWORD_REJECTED = (1, "incorrect password attempt")
    SUDO_PASSWORD_REQUIRED = (1, "a password is required")

    started = time.time()

    def stage(message):
        print(f"\n========== [t+{time.time() - started:6.1f}s] {message} ==========")

    def succeed(machine, command):
        return machine.succeed(command, timeout=COMMAND_TIMEOUT)

    def shadow_hash(machine, user):
        return succeed(machine, f"getent shadow {user} | cut -d: -f2").strip()

    def expect_denied(machine, command, denial, label):
        expected_status, expected_reason = denial
        status, output = machine.execute(f"{command} 2>&1", timeout=COMMAND_TIMEOUT)
        assert status == expected_status and expected_reason in output, (
            f"{label}: status={status}, expected_status={expected_status}, "
            f"expected_reason={expected_reason!r}, output={output!r}"
        )

    def sudo_command(password, user="test-user"):
        return (
            f"printf '%s\\n' '{password}' "
            f"| runuser -u {user} -- sudo -S -k true"
        )

    stage("boot all authentication policies")
    start_all()
    for machine in (laptop, server, shared):
        machine.wait_for_unit("multi-user.target", timeout=BOOT_TIMEOUT)
        machine.wait_for_unit("sshd.service", timeout=COMMAND_TIMEOUT)
        machine.wait_for_open_port(22, timeout=COMMAND_TIMEOUT)

    stage("password hashes target opposite accounts")
    assert shadow_hash(laptop, "test-user").startswith("$6$")
    assert shadow_hash(laptop, "root") == "!"
    assert shadow_hash(server, "test-user") == "!"
    assert shadow_hash(server, "root").startswith("$6$")

    stage("shared host gives every sudo account its own password hash")
    shared_owner_hash = shadow_hash(shared, "test-user")
    shared_guest_hash = shadow_hash(shared, "guest-user")
    assert shared_owner_hash.startswith("$6$")
    assert shared_guest_hash.startswith("$6$")
    assert shared_owner_hash != shared_guest_hash
    assert shadow_hash(shared, "root") == "!"

    stage("install public test credential")
    for machine in (laptop, server):
        succeed(machine, "install -m 0600 ${testKeys.admin.privateKey} /tmp/test-identity")

    ssh_key_options = (
        "-n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o BatchMode=yes -o ConnectTimeout=10"
    )
    ssh_password_options = (
        "-n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o PreferredAuthentications=password -o PubkeyAuthentication=no "
        "-o NumberOfPasswordPrompts=1 -o ConnectTimeout=10"
    )

    stage("normal users log in with keys, including locked server user")
    for machine in (laptop, server):
        succeed(machine, f"ssh {ssh_key_options} -i /tmp/test-identity test-user@localhost true")

    stage("direct root SSH is denied despite an authorized key")
    for machine in (laptop, server):
        expect_denied(
            machine,
            f"ssh {ssh_key_options} -i /tmp/test-identity root@localhost true",
            SSH_DENIED,
            "root SSH",
        )

    stage("password SSH is denied even for accounts with valid passwords")
    expect_denied(
        laptop,
        f"sshpass -p laptop-password ssh {ssh_password_options} test-user@localhost true",
        SSH_DENIED,
        "laptop user password SSH",
    )
    expect_denied(
        server,
        f"sshpass -p server-root-password ssh {ssh_password_options} root@localhost true",
        SSH_DENIED,
        "server root password SSH",
    )

    stage("laptop sudo authenticates with owner password")
    succeed(laptop, sudo_command("laptop-password"))
    expect_denied(
        laptop,
        sudo_command("server-root-password"),
        SUDO_PASSWORD_REJECTED,
        "laptop root password",
    )

    stage("server sudo authenticates with root password")
    succeed(server, sudo_command("server-root-password"))
    expect_denied(
        server,
        sudo_command("laptop-password"),
        SUDO_PASSWORD_REJECTED,
        "server user password",
    )

    stage("shared host sudo authenticates each account with its own password")
    succeed(shared, sudo_command("shared-owner-password"))
    succeed(shared, sudo_command("guest-password", user="guest-user"))
    expect_denied(
        shared,
        sudo_command("shared-owner-password", user="guest-user"),
        SUDO_PASSWORD_REJECTED,
        "guest with owner password",
    )
    expect_denied(
        shared,
        sudo_command("guest-password"),
        SUDO_PASSWORD_REJECTED,
        "owner with guest password",
    )

    stage("non-interactive sudo remains denied")
    for machine in (laptop, server, shared):
        expect_denied(
            machine,
            "runuser -u test-user -- sudo -k -n true",
            SUDO_PASSWORD_REQUIRED,
            "passwordless sudo",
        )

    stage("generated policy is explicit")
    assert "Defaults:%wheel rootpw" not in succeed(laptop, "cat /etc/sudoers")
    assert "Defaults:%wheel rootpw" not in succeed(shared, "cat /etc/sudoers")
    assert "Defaults:%wheel rootpw" in succeed(server, "cat /etc/sudoers")
    for machine in (laptop, server, shared):
        sshd = succeed(machine, "cat /etc/ssh/sshd_config")
        assert "PasswordAuthentication no" in sshd
        assert "KbdInteractiveAuthentication no" in sshd
        assert "PermitRootLogin no" in sshd

    print("BOOTSTRAP AUTHENTICATION POLICY VERIFIED")
  '';
}
