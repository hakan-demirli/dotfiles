{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{

  flake.modules.nixos.services-sops =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.sops;
      mkPubKey = path: content: "L+ ${path} - - - - ${pkgs.writeText (baseNameOf path) content}";
      inherit (cfg) username;

      gitSignConfigFile = ''
        [user]
          signingkey = ${publicData.yubikey.gpg_key_id}
        [commit]
          gpgsign = true
      '';
    in
    {
      options.services.sops = {
        username = lib.mkOption {
          type = lib.types.str;
          default = "emre";
          description = "Username for sops secrets ownership";
        };
        defaultSopsFile = lib.mkOption {
          type = lib.types.path;
          default = inputs.self + /secrets/secrets.yaml;
          description = "Default sops secrets file";
        };
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/persist/system/var/lib/sops-nix/key.txt";
          description = "Path to age key file";
        };
      };

      config = {
        sops = {
          inherit (cfg) defaultSopsFile;
          defaultSopsFormat = "yaml";
          age.keyFile = cfg.ageKeyFile;

          secrets = {
            "ssh/config" = {
              owner = username;
              path = "/home/${username}/.ssh/config";
            };
            "ssh/id_ed25519" = {
              owner = username;
              path = "/home/${username}/.ssh/id_ed25519";
              mode = "0600";
            };
            "root_id_ed25519_proton" = {
              key = "ssh/id_ed25519_proton";
              owner = "root";
              path = "/root/.ssh/id_ed25519_proton";
              mode = "0600";
            };
            "root_ssh_config" = {
              key = "ssh/config";
              owner = "root";
              path = "/root/.ssh/config";
              mode = "0600";
            };
            "ssh/id_ed25519_proton" = {
              owner = username;
              path = "/home/${username}/.ssh/id_ed25519_proton";
              mode = "0600";
            };
            "ssh/id_ed25519_sf" = {
              owner = username;
              path = "/home/${username}/.ssh/id_ed25519_sf";
              mode = "0600";
            };
            "ssh/gh_action_key" = {
              owner = username;
              path = "/home/${username}/.ssh/gh_action_key";
              mode = "0600";
            };

            "git_tokens" = {
              owner = username;
              path = "/home/${username}/.config/git/git_tokens";
            };
            "git_users" = {
              owner = username;
              path = "/home/${username}/.config/git/git_users";
            };

            "nixauth" = {
              owner = username;
              path = "/home/${username}/.config/nix/nixauth";
            };

            "environment" = {
              owner = username;
              path = "/home/${username}/.config/secrets/environment";
            };
            "questa_license.dat" = {
              owner = username;
              path = "/home/${username}/.config/secrets/questa_license.dat";
            };
          };
        };

        systemd.tmpfiles.rules = [
          "d /home/${username}/.ssh 0700 ${username} users -"
          "d /home/${username}/.config 0755 ${username} users -"
          "d /home/${username}/.config/git 0755 ${username} users -"
          "d /home/${username}/.config/nix 0755 ${username} users -"
          "d /home/${username}/.config/secrets 0755 ${username} users -"

          (mkPubKey "/home/${username}/.ssh/id_ed25519.pub" publicData.ssh.id_ed25519_pub)
          (mkPubKey "/home/${username}/.ssh/id_ed25519_proton.pub" publicData.ssh.id_ed25519_proton_pub)
          (mkPubKey "/home/${username}/.ssh/id_ed25519_sf.pub" publicData.ssh.id_ed25519_sf_pub)
          (mkPubKey "/home/${username}/.ssh/gh_action_key.pub" publicData.ssh.gh_action_key_pub)
          (mkPubKey "/home/${username}/.config/git/git_sign" gitSignConfigFile)
        ];

        environment.persistence."/persist/system".directories = [
          "/var/lib/sops-nix"
        ];
      };
    };
}
