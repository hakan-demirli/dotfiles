{
  id = "developer";
  description = "Key-authenticated SSH for collaborators. No sudo, no root login";
  groups = [ ];
  sudo.extra_rule = null;
  ssh.allowed = true;
  root_ssh = false;
}
