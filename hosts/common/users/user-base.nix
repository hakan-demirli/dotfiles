{
  lib,
  pkgs,
  inputs,
  username ? throw "You must define a username",
  uid ? 1000,
  hashedPassword ? throw "You must define a hashedPassword",
  extraGroups ? [ ],
  authorizedKeys ? [ ],
  useHomeManager ? true,
  homeManagerImports ? [ ],
  homeManagerArgs ? { },
  ...
}:

let
  commonGroups = [
    "networkmanager"
    "wheel"
    "audio"
    "video"
    "input"
    "uinput"
    "libvirtd"
    "docker"
  ];
  allGroups = lib.unique (commonGroups ++ extraGroups);
in
{
  users.users.${username} = {
    isNormalUser = true;
    inherit uid hashedPassword;
    extraGroups = allGroups;
    openssh.authorizedKeys.keys = authorizedKeys;

    linger = true;
  };

  home-manager = lib.mkIf useHomeManager {
    extraSpecialArgs = {
      inherit inputs pkgs;
    }
    // homeManagerArgs;
    backupFileExtension = "backup";
    users.${username} = {
      imports = homeManagerImports;
    };
  };

  programs.fuse.userAllowOther = true;
}
