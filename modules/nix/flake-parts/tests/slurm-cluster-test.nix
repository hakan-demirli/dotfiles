{ self, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      apps.test-slurm-cluster = {
        type = "app";
        program = "${config.packages.slurm-cluster-test.driver}/bin/nixos-test-driver";
        meta.description = "Boot the real SLURM cluster config (vm-oracle-aarch64 + s01 + s02 + laptop submitter) in VMs and verify munge/auth/nodes/jobs";
      };

      packages.slurm-cluster-test =
        let
          clusterHosts = ''
            192.168.1.1 vm-oracle-aarch64
            192.168.1.2 s01
            192.168.1.3 s02
            192.168.1.4 submitter
          '';

          computeNode =
            { lib, ... }:
            {
              imports = with self.modules.nixos; [
                services-slurm
                slurm-cluster-nodes
              ];
              services.slurm-cluster.enable = true;
              services.slurm.extraConfig = lib.mkAfter ''
                SlurmdParameters=config_overrides
                ReturnToService=2
              '';
              services.timesyncd.enable = lib.mkForce false;
              networking.extraHosts = clusterHosts;
              networking.firewall.enable = false;
              virtualisation = {
                memorySize = 2048;
                cores = 2;
              };
            };
        in
        pkgs.testers.runNixOSTest {
          name = "slurm-cluster-test";

          nodes = {
            controller =
              { lib, ... }:
              {
                imports = [ computeNode ];
                networking.hostName = lib.mkForce "vm-oracle-aarch64";
                services.slurm-cluster.isMaster = true;
              };

            s01 =
              { lib, ... }:
              {
                imports = [ computeNode ];
                networking.hostName = lib.mkForce "s01";
                services.slurm-cluster.isMaster = false;
              };

            s02 =
              { lib, ... }:
              {
                imports = [ computeNode ];
                networking.hostName = lib.mkForce "s02";
                services.slurm-cluster.isMaster = false;
              };

            submitter =
              { lib, ... }:
              {
                imports = [ self.modules.nixos.services-slurm-client ];
                networking.hostName = lib.mkForce "submitter";
                networking.extraHosts = clusterHosts;
                networking.firewall.enable = false;
                services.slurm-client = {
                  enable = true;
                  masterHostname = "vm-oracle-aarch64";
                };
                services.timesyncd.enable = lib.mkForce false;
                virtualisation = {
                  memorySize = 1024;
                  cores = 1;
                };
              };
          };

          testScript = ''
            start_all()

            slurm_nodes = [controller, s01, s02]
            all_nodes = slurm_nodes + [submitter]

            with subtest("munge + slurm daemons come up"):
                for n in all_nodes:
                    n.wait_for_unit("munged.service")
                controller.wait_for_unit("slurmctld.service")
                for n in slurm_nodes:
                    n.wait_for_unit("slurmd.service")

            with subtest("structural invariants (catches munge deletion under auth/none)"):
                for n in all_nodes:
                    n.succeed("systemctl is-active munged.service")
                    n.succeed("test -f /etc/munge/munge.key")
                    perms = n.succeed("stat -c %a /etc/munge/munge.key").strip()
                    assert perms == "400", f"munge.key perms = {perms}, expected 400"
                cfg = controller.succeed("scontrol show config")
                assert "auth/none" in cfg, f"AuthType is not auth/none:\n{cfg}"

            with subtest("all nodes reach IDLE"):
                controller.succeed(
                    """
                    for i in $(seq 1 90); do
                        idle=$(sinfo -h -N -o '%T' | grep -c idle || true)
                        if [ "$idle" -ge 3 ]; then
                            echo "all 3 slurm nodes idle"; sinfo -N; exit 0
                        fi
                        scontrol update nodename=vm-oracle-aarch64 state=resume 2>/dev/null || true
                        scontrol update nodename=s01 state=resume 2>/dev/null || true
                        scontrol update nodename=s02 state=resume 2>/dev/null || true
                        sleep 2
                    done
                    echo "timeout waiting for idle nodes"; sinfo -N; scontrol show nodes; exit 1
                    """
                )

            with subtest("functional: srun runs across the real compute partition (s01,s02)"):
                out = controller.succeed("srun -N2 -p compute hostname")
                print("srun output:\n" + out)
                assert "s01" in out and "s02" in out, f"job did not run on both workers: {out!r}"

            with subtest("submit path from laptop module (services-slurm-client)"):
                submitter.succeed("squeue >&2")
                submitter.succeed(
                    "sbatch -p compute -N1 --wrap='hostname > /tmp/job.out' -o /tmp/sbatch.log"
                )
                controller.succeed(
                    """
                    for i in $(seq 1 60); do
                        if ! squeue -h | grep -q .; then echo "queue drained"; exit 0; fi
                        sleep 2
                    done
                    echo "timeout waiting for submitted job"; squeue; sacct 2>/dev/null || true; exit 1
                    """
                )

            print("SLURM CLUSTER VERIFICATIONS PASSED")
          '';
        };
    };
}
