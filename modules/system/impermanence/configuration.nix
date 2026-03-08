{
  flake.modules.nixos.system-impermanence =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.system.impermanence;
    in
    {
      options.system.impermanence = {
        username = lib.mkOption {
          type = lib.types.str;
          default = "emre";
        };
        uid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
        };
        persistentDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        persistentUserDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "Desktop"
            "Documents"
            "Downloads"
            "Videos"
            ".cache"
            ".local/share"
            ".local/state/opencode"
            ".config/opencode"
            ".antigravity"
            ".config/Antigravity"
            ".gemini"
          ];
          description = "Base user directories to persist (relative to home)";
        };
        extraPersistentUserDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra user directories to persist, appended to persistentUserDirs";
        };
      };

      config = {
        fileSystems."/persist".neededForBoot = true;

        environment.persistence."/persist/system" = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
            "/etc/NetworkManager/system-connections"
            "/root/.cache/nix"
          ]
          ++ cfg.persistentDirs;
        };

        environment.persistence."/persist" = {
          hideMounts = true;
          users.${cfg.username} = {
            directories = cfg.persistentUserDirs ++ cfg.extraPersistentUserDirs;
          };
        };

        systemd.tmpfiles.rules = [
          "d /persist/home/ 0777 root root -"
          "d /persist/home/${cfg.username} 0700 ${toString cfg.uid} users -"
        ];
      };
    };
}
