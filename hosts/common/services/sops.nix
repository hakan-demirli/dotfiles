_: {
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

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
      "ssh/id_ed25519.pub" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519.pub";
        mode = "0644";
      };
      "ssh/id_ed25519_proton" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_proton";
        mode = "0600";
      };
      "ssh/id_ed25519_proton.pub" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_proton.pub";
        mode = "0644";
      };
      "ssh/id_ed25519_sf" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_sf";
        mode = "0600";
      };
      "ssh/id_ed25519_sf.pub" = {
        owner = "emre";
        path = "/home/emre/.ssh/id_ed25519_sf.pub";
        mode = "0644";
      };

      "git_tokens" = {
        owner = "emre";
        path = "/home/emre/.config/git/git_tokens";
      };
      "git_users" = {
        owner = "emre";
        path = "/home/emre/.config/git/git_users";
      };
      "git_keys" = {
        owner = "emre";
        path = "/home/emre/.config/git/git_keys";
      };

      "nixauth" = {
        owner = "emre";
        path = "/home/emre/.config/nix/nixauth";
      };

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
    "d /home/emre/.config/git 0755 emre users -"
    "d /home/emre/.config/nix 0755 emre users -"
    "d /home/emre/.config/secrets 0755 emre users -"
  ];

  environment.persistence."/persist/system".directories = [
    "/var/lib/sops-nix"
  ];
}
