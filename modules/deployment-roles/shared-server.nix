{
  cluster,
  host,
  lib,
  pkgs,
  ...
}:
let
  guestPrincipals = (import ../../inventory/tailnet-acl.nix).groups."group:shared-server-users";
  guestIds = map (lib.removeSuffix "@") guestPrincipals;
  guestOnHost =
    id:
    let
      user = cluster.users.${id};
    in
    !(user.archived or false)
    && (lib.elem "all" user.allowed_hosts || lib.elem host.id user.allowed_hosts);
  guestUsers = lib.listToAttrs (
    map (
      id:
      let
        user = cluster.users.${id};
        account = user.system_account;
      in
      if account == null then
        throw "shared-server: guest '${id}' requires a system account"
      else
        lib.nameValuePair account.username {
          isNormalUser = true;
          inherit (account) uid;
          shell = pkgs.bashInteractive;
          extraGroups = lib.unique (account.groups ++ cluster.unixAccessTiers.admin.groups);
          openssh.authorizedKeys.keys = user.keys.ssh;
          hashedPasswordFile = "/run/bootstrap-secrets/password-hash";
        }
    ) (lib.filter guestOnHost guestIds)
  );
in
{
  services = {
    openssh.settings.PermitRootLogin = lib.mkForce "no";
    sops.bootstrap.passwordAccount = "owner";
    tailscale.loginServerHost = "sshr.polarbearvuzi.com";
  };

  networking.networkmanager.enable = true;
  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = true;

  users.users = guestUsers;

  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
  };
}
