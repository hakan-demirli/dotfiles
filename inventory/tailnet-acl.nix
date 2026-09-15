[
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
]
