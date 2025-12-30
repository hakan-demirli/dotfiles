{
  flake.modules.nixos.user-base = { config, pkgs, lib, inputs, ... }: {
    options.system.user = {
      username = lib.mkOption { type = lib.types.str; };
      uid = lib.mkOption { type = lib.types.int; default = 1000; };
      hashedPassword = lib.mkOption { type = lib.types.str; };
      authorizedKeys = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
      extraGroups = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
      useHomeManager = lib.mkEnableOption "home-manager";
      homeManagerImports = lib.mkOption { type = lib.types.listOf lib.types.anything; default = []; };
    };

    config = {
      users.users.${config.system.user.username} = {
        isNormalUser = true;
        inherit (config.system.user) uid hashedPassword;
        extraGroups = lib.unique ([ "networkmanager" "wheel" "audio" "video" "input" "uinput" "libvirtd" "docker" ] ++ config.system.user.extraGroups);
        openssh.authorizedKeys.keys = config.system.user.authorizedKeys;
        linger = true;
      };

      home-manager = lib.mkIf config.system.user.useHomeManager {
        extraSpecialArgs = { inherit inputs pkgs; };
        backupFileExtension = "backup";
        users.${config.system.user.username} = {
          imports = config.system.user.homeManagerImports;
        };
      };
      programs.fuse.userAllowOther = true;
    };
  };
}
