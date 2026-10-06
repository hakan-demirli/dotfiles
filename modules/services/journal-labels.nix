{
  config,
  cluster,
  lib,
  ...
}:
let
  accounts = lib.filter (account: account != null) (
    map (user: user.system_account or null) (lib.attrValues cluster.users)
  );
  usernames = lib.listToAttrs (
    map (account: {
      name = toString account.uid;
      value = account.username;
    }) accounts
  );
in
{
  services.vector.settings = lib.mkIf config.services.vector.enable {
    transforms.journal-context = {
      type = "remap";
      inputs = [ "label" ];
      source = ''
        .journal_unit = .unit
        .manager = "system"
        user_unit = ._SYSTEMD_USER_UNIT
        if user_unit == null { user_unit = .USER_UNIT }
        if user_unit != null {
          .unit = user_unit
          uid = to_string(._UID) ?? "unknown"
          usernames = ${builtins.toJSON usernames}
          .manager = get(usernames, [uid]) ?? uid
        } else if .UNIT != null {
          .unit = .UNIT
        }
      '';
    };
    sinks.victorialogs.inputs = lib.mkForce (
      [ "journal-context" ]
      ++ lib.optional (config.services.vector.settings.transforms ? router-label) "router-label"
    );
  };
}
