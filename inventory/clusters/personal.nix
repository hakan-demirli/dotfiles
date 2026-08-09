{
  id = "personal";
  description = "Personal slurm cluster. Single-user fleet";
  kind = "personal";
  state = "active";

  lifecycle.created_at = "2025-01-01";

  ownership = {
    class = "personal";
    team = "team-user-0";
  };

  scheduler = {
    kind = "slurm";
    controllers = [ "vps-oracle-0" ];
    partitions.laptops = {
      nodes = [ "laptop-0" ];
      default = true;
      max_time = "01:00:00";
    };
    partitions.servers = {
      nodes = [
        "server-dev-1"
        "server-dev-2"
      ];
      default = false;
      max_time = "24:00:00";
    };
  };

  members = {
    hosts = [ ];
    deployment_roles = [
      "personal-laptop"
      "personal-server-dev"
    ];
  };

  access = {
    users = [ ];
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
    tailscale_tag = "tag:cluster-personal";
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

  labels.scope = "personal";
}
