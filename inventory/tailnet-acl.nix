{
  groups."group:shared-server-users" = [ "guest-0@" ];

  tagOwners."tag:shared-server-login" = [ "group:admin" ];

  acls = [
    {
      action = "accept";
      src = [ "group:shared-server-users" ];
      dst = [ "tag:shared-server-login:22" ];
    }
    {
      action = "accept";
      src = [ "tag:cluster-router-0" ];
      dst = [ "tag:cluster-user-0-fleet-controller:5514" ];
    }
    {
      action = "accept";
      src = [ "tag:cluster-user-0-fleet" ];
      dst = [ "tag:cluster-user-0-fleet-controller:8111" ];
    }
  ];
}
