{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  wifiKeyFile = "/home/emre/.config/sops/age/wifi.key";
  wifiSopsFile = inputs.self + /secrets/wifi/credentials.yaml;
  wifiProfilesDirectory = "/run/NetworkManager/system-connections";
  transferInbox = "/persist/home/emre/paths/Downloads/Inbox";
  transferSources = [
    "100.64.0.1" # vps-oracle-0
    "100.64.0.2" # server-dev-1
  ];
  wifiProfiles = [
    {
      uuid = "1ac6867b-3ced-4010-bbde-be66b5565917";
    }
    {
      uuid = "ad484072-5ce8-433b-83d5-ac2c8cec277b";
    }
    {
      uuid = "2ee6e19e-f648-4d30-bfd3-2cd12ee76420";
    }
    {
      uuid = "a13ba30e-bcec-4fb1-83f6-213dbcee7ed6";
    }
    {
      uuid = "cfd5ad59-995c-46e3-9629-acc2f7e4460d";
    }
    {
      uuid = "27e074b3-a897-4eb4-af24-187c8030c10f";
    }
    {
      uuid = "6c3af4f0-e688-4b95-8211-3f63340b66d1";
    }
    {
      uuid = "45e62878-7b44-487c-8e60-6ab8f327ef44";
    }
    {
      uuid = "fd12a2d2-d296-4474-83fd-32e6562c12b1";
    }
    {
      uuid = "b7e93780-8c11-475c-bc42-adb86362352f";
    }
  ];
  installWifiProfiles = pkgs.writeShellApplication {
    name = "install-networkmanager-sops-profiles";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.networkmanager
      pkgs.sops
    ];
    text = ''
      key_file=${lib.escapeShellArg wifiKeyFile}
      sops_file=${lib.escapeShellArg wifiSopsFile}
      output_dir=${lib.escapeShellArg wifiProfilesDirectory}
      persisted_dir=/etc/NetworkManager/system-connections

      if [[ ! -s "$key_file" ]]; then
        echo "Wi-Fi SOPS identity is missing: $key_file" >&2
        exit 1
      fi

      install -d -m 0700 "$output_dir"
      staging="$(mktemp -d /run/networkmanager-sops-profiles/.staging.XXXXXX)"
      trap 'rm -rf "$staging"' EXIT

      ${lib.concatMapStringsSep "\n" (profile: ''
        if ! contents="$(SOPS_AGE_KEY_FILE="$key_file" sops --decrypt \
          --extract ${
            lib.escapeShellArg (
              lib.concatMapStrings (component: "[${builtins.toJSON component}]") [
                "profiles"
                profile.uuid
              ]
            )
          } \
          "$sops_file")"; then
          echo "Unable to decrypt NetworkManager profile ${profile.uuid}" >&2
          exit 1
        fi
        if [[ "$contents" != *"uuid=${profile.uuid}"* ]]; then
          echo "NetworkManager profile ${profile.uuid} has the wrong UUID" >&2
          exit 1
        fi
        printf '%s\n' "$contents" > "$staging/${profile.uuid}.nmconnection"
        chmod 0600 "$staging/${profile.uuid}.nmconnection"
        unset contents
      '') wifiProfiles}

      ${lib.concatMapStringsSep "\n" (profile: ''
        mv -f "$staging/${profile.uuid}.nmconnection" \
          "$output_dir/${profile.uuid}.nmconnection"
      '') wifiProfiles}
      rmdir "$staging"
      trap - EXIT

      for persisted_profile in "$persisted_dir"/*.nmconnection; do
        [[ -e "$persisted_profile" ]] || continue
        remove_profile=false
        while IFS= read -r line; do
          case "$line" in
            ${lib.concatMapStringsSep "|" (profile: "uuid=${profile.uuid}") wifiProfiles})
              remove_profile=true
              break
              ;;
          esac
        done < "$persisted_profile"
        if [[ $remove_profile == true ]]; then
          rm -f "$persisted_profile"
        fi
      done
      nmcli connection reload
    '';
  };
in
{
  imports = [
    inputs.infra-lib.nixosModules.system-intel
    "${inputs.infra-lib}/modules/services/fprintd.nix"
    "${inputs.infra-lib}/modules/services/desktop/tablet.nix"
    ../system/overlays.nix
  ];

  services = {
    openssh.enable = lib.mkForce false;

    rsyncd = {
      enable = true;
      socketActivated = true;
      settings = {
        globalSection = {
          uid = "emre";
          gid = "users";
          "use chroot" = true;
          "max connections" = 4;
          "reverse lookup" = false;
        };
        sections.inbox = {
          path = transferInbox;
          comment = "Write-only file inbox for trusted tailnet nodes";
          "read only" = false;
          "write only" = true;
          list = false;
          "hosts allow" = lib.concatStringsSep " " transferSources;
          "hosts deny" = "*";
          "incoming chmod" = "Du=rwx,Dgo=,Fu=rw,Fgo=";
          "munge symlinks" = true;
          "refuse options" = "delete delete-before delete-during delete-delay delete-after delete-excluded";
          timeout = 600;
        };
      };
    };

    slurm-client.enable = true;
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
    };
  };

  systemd = {
    sockets.rsync = {
      after = [ "tailscaled.service" ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      requires = [ "tailscaled.service" ];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = [ transferInbox ];
      };
      socketConfig.BindToDevice = "tailscale0";
    };

    tmpfiles.rules = [
      "d ${transferInbox} 0700 emre users -"
    ];

    services = {
      munged = {
        unitConfig.ConditionPathExists = "/etc/munge/munge.key";
        serviceConfig = {
          ExecStartPre = lib.mkForce "-+${pkgs.coreutils}/bin/chmod 0400 /etc/munge/munge.key";
          ExecStart = lib.mkForce "-${pkgs.munge}/bin/munged --foreground --key-file /etc/munge/munge.key";
          Restart = lib.mkForce "no";
        };
      };

      networkmanager-sops-profiles = {
        description = "Install SOPS-backed NetworkManager profiles";
        wantedBy = [ "multi-user.target" ];
        requires = [ "NetworkManager.service" ];
        after = [ "NetworkManager.service" ];
        restartTriggers = [ wifiSopsFile ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "networkmanager-sops-profiles";
          RuntimeDirectoryMode = "0700";
          ExecStart = "${installWifiProfiles}/bin/install-networkmanager-sops-profiles";
        };
      };
    };
  };

  networking.useDHCP = lib.mkDefault true;

  environment.etc."libinput/local-overrides.quirks".text = ''
    [ELAN2513 Metapen MCP2 Stylus Pressure]
    MatchName=ELAN2513:00 04F3:4302 Stylus
    MatchBus=i2c
    AttrPressureRange=40:10
  '';

  boot = {
    kernelParams = [ "video.brightness_switch_enabled=0" ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "riscv64-linux"
    ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "fs.file-max" = "20480000";
      "fs.inotify.max_user_watches" = "20480000";
      "fs.inotify.max_user_instances" = "20480000";
      "fs.inotify.max_queued_events" = "20480000";
      "kernel.perf_event_paranoid" = 1;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [
      "ntfs"
      "xfs"
    ];
  };
}
