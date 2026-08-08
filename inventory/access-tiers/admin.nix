{
  id = "admin";
  description = "Key-authenticated SSH. Host policy controls sudo authentication";
  extra_groups = [ "wheel" ];
  sudo = null;
  ssh.allowed = true;
}
