{
  id = "admin";
  description = "Key-authenticated SSH. Host policy controls sudo authentication";
  groups = [
    "wheel"
    "apptainer"
    "kvm"
    "libvirtd"
    "networkmanager"
    "audio"
    "video"
    "input"
  ];
  sudo.extra_rule = null;
  ssh.allowed = true;
  root_ssh = true;
}
