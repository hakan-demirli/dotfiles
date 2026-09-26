{
  id = "shared-server-1";
  description = "Standalone multi-user server";
  kind = "shared";
  state = "active";

  ownership = {
    class = "borrowed";
    team = "team-user-0";
  };

  scheduler.kind = "none";
  members = {
    hosts = [ "shared-server-1" ];
    deployment_roles = [ ];
  };

  access = {
    users = [
      {
        user = "guest-0";
        unix_tier = "admin";
      }
    ];
    teams = [
      {
        team = "team-user-0";
        unix_tier = "admin";
        can_submit_to = [ ];
      }
    ];
  };

  network = {
    intra_cluster = "mesh";
    egress = {
      clusters = [ ];
      internet = true;
    };
    ingress = {
      clusters = [ ];
      public = [ ];
    };
  };

  keys = {
    ssh = [ ];
    age = [ ];
  };
}
