{
  id = "admin";
  description = "sudo, all slurm partitions, no caps";
  sudo = "NOPASSWD:ALL";
  ssh.allowed = true;
  slurm_qos = {
    max_wall = "INFINITE";
    priority = 1000;
  };
}
