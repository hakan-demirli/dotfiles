{ pkgs, ... }:

let
  publicData = builtins.fromTOML (builtins.readFile ../../../secrets/public.toml);
  mkPubKey = path: content: "L+ ${path} - - - - ${pkgs.writeText (baseNameOf path) content}";

  gitSignConfigFile = ''
    [user]
      signingkey = ${publicData.yubikey.gpg_key_id}
    [commit]
      gpgsign = true
  '';
in
{

  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/persist/system/var/lib/sops-nix/key.txt";

    secrets = {
      "tailscale-key" = { };

      "ssh/config" = {
        owner = "emre";
        path = "/home/emre/.ssh/config";
      };
      "ssh/id_ed25519" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519";
        mode = "0600";
      };
      "ssh/id_ed25519_proton" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_proton";
        mode = "0600";
      };
      "ssh/id_ed25519_sf" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_sf";
        mode = "0600";
      };
      "ssh/gh_action_key" = {
        owner = "emre";
        path = "/home/emre/.ssh/gh_action_key";
        mode = "0600";
      };

      "git_tokens" = {
        owner = "emre";
        path = "/home/emre/.config/git/git_tokens";
      };
      "git_users" = {
        owner = "emre";
        path = "/home/emre/.config/git/git_users";
      };

      "nixauth" = {
        owner = "emre";
        path = "/home/emre/.config/nix/nixauth";
      };

      "nix-serve-key" = { };

      "environment" = {
        owner = "emre";
        path = "/home/emre/.config/secrets/environment";
      };
      "questa_license.dat" = {
        owner = "emre";
        path = "/home/emre/.config/secrets/questa_license.dat";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/emre/.ssh 0700 emre users -"
    "d /home/emre/.config 0755 emre users -"
    "d /home/emre/.config/git 0755 emre users -"
    "d /home/emre/.config/nix 0755 emre users -"
    "d /home/emre/.config/secrets 0755 emre users -"

    (mkPubKey "/home/emre/.ssh/id_ed25519.pub" publicData.ssh.id_ed25519_pub)
    (mkPubKey "/home/emre/.ssh/id_ed25519_proton.pub" publicData.ssh.id_ed25519_proton_pub)
    (mkPubKey "/home/emre/.ssh/id_ed25519_sf.pub" publicData.ssh.id_ed25519_sf_pub)
    (mkPubKey "/home/emre/.ssh/gh_action_key.pub" publicData.ssh.gh_action_key_pub)
    (mkPubKey "/home/emre/.config/git/git_sign" gitSignConfigFile)
  ];

  environment.persistence."/persist/system".directories = [
    "/var/lib/sops-nix"
  ];
}
