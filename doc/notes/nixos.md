* **virt-manager copy paste clipboard functionality to the windows vm**
    * Install spice-guest-tools on Windows guest; https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe

* **Use local nixpkgs before PR to compile your app**
    * Add your app to pkgs-byname etc. as ususal.
    * Go to root of the nixpkgs.
    * Assuming your new package is named `bonk`
    * ```nix-build -A bonk```

* **List of linting tools for Nix**
    * ```nix run github:nix-community/nixpkgs-lint -- ./file.nix```
    * ```nix run nixpkgs#statix -- check```
    * ```nix run nixpkgs#deadnix```

* **Create your config as custom iso**
    * Ensure `hardware-configuration.nix` etc. is not included in your configuration.nix
    ```nix
    nixosConfigurations.isoimage = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
      ];
    };
    ```

* **Enable Swap**
    * No impermanence:
        * ``` swapDevices = [ { device = "/var/lib/swapfile"; size = 30 * 1024; } ]; ```
    * With impermance and disko:
        * Use dedicated volume, not subvolume or swapfile.
            * You dont want to rewrite 32GBs of data on every boot.
        * Create a swap volume in disko.

* **Using nixGL to fix OpenGL applications on non-NixOS distributions**
    * https://pmiddend.github.io/posts/nixgl-on-ubuntu/

* **Get home-manager generated files/outputs without activating**
    * `home-manager build --flake ~/Desktop/dotfiles/#emre`

* **List exported binaries**
    * ls -al $(nix-build --no-out-link '<nixpkgs>' -A gcc)/bin/`

* **Restart touchpad driver**
    * Find kernel module responsible for the touchpad:
        * `lsmod`
            * Its probably one of these:
                * `hid_generic`
                * `hid_multitouch`
                * `psmouse`
                * `i2c_hid_acpi`
    * Kill it:
        * `sudo modprobe -r hid_generic`
    * Restart it:
        * `sudo modprobe hid_generic`

* **What is configuration.nix file?**
    * It's default location is: ```/etc/nixos/configuration.nix```
    * It controls the OS configuration. You want to install a package, modify it.
    * It is a bad practice to leave it in it's default location. Use flakes instead.

* **Where to find packages**
    * https://search.nixos.org/packages

* **Install git**
    * Temporarily:
        * ```nix shell -p nixpkgs#git```
    * Via configuration.nix
        * ```sudo nano /etc/nixos/configuration.nix```
        ```nix
            environment.systemPackages = with pkgs; [
            gitMinimal  ];
        ```
        * ```sudo nixos-rebuild switch```

* **Enable NTFS support**
    * ```sudo nano /etc/nixos/configuration.nix```
    * Add
        * ```boot.supportedFilesystems = [ "ntfs" ];```
    * ```sudo nixos-rebuild switch```

* **Enable flakes**
    * Via configuration.nix
        *
        ```nix
            { pkgs, ... }: {
                nix.settings.experimental-features = [ "nix-command" "flakes" ];
            }
        ```
        * ```sudo nixos-rebuild switch```
    * Temporarily:
        * ```export NIX_CONFIG="experimental-features = nix-command flakes"```

* **Install home-manager for current shell**
    * ```nix shell nixpkgs#home-manager```

* **How to bootstrap flake.nix with home-manager**
    * Enable flakes
    * Install home-manager.
    * ```sudo nixos-rebuild switch --flake .#nixos```
    * ```home-manager switch --flake .#emre@nixos```

* **Using flakes for configuration.nix and user settings**
    * [Repo.](https://github.com/Misterio77/nix-starter-configs)
    * [Tutorial.](https://cola-gang.industries/nixos-for-the-confused-part-i)
    * The home-manager directory will hold our Home Manager (user) stuff.
    * The nixos directory will hold our configuration.nix.
    * flake.nix file will tell NixOS how to handle both.
    * The flake.lock file will be generated automatically. Ensures versions.
    ```
        ├── flake.lock
        ├── flake.nix
        ├── home-manager
        │   └── home.nix
        └── nixos
            ├── configuration.nix
            └── hardware-configuration.nix
    ```

* **Installing Nvidia Drivers**
    * [Manual](https://nixos.wiki/wiki/Nvidia)

* **How to rollback home-manager**
    * ```home-manager generations```
    * Choose a generation and run the activate string inside it. Example:
        * ```/nix/store/<hash_of_the_generation_you_have_chosen>-home-manager-generation/activate```

* **How to mount disks at boot**
    *  Every time you rebuild the system, the fstab file is changed according to the (by default) hardware-configuration.nix file. So, you have to add your disks to hardware-configuration.nix to make it mount at default.
    * You may try to mount them via gnome-disks and then generate a config file by running ```nixos-generate-config```. But, this will not work as there is [a bug](https://github.com/NixOS/nixpkgs/issues/14624) in Nixos.
    * Hence, only option is to add them manually. Add this to hardware-configuration.nix:
    ```nix
      fileSystems."/mnt/second" =
        {
            device = "/dev/disk/by-uuid/0D11E693467F5A53";
            options = [ "uid=1000" "gid=1000" "dmask=007" "fmask=117" ];
        };
    ```

* **Add VM to virt-manager via cli**
    * ```sudo virsh net-start default```
    * ```sudo virt-install   --name win11   --memory 9999   --vcpus 16   --disk path=./win11.qcow2,size=80   --cdrom ./windows10.iso   --os-variant win11   --network network=default   --graphics spice   --boot cdrom,hd --noreboot --noautoconsole```
    * ```sudo virt-install   --name ubuntu24   --memory 9999   --vcpus 16   --disk path=./ubuntu24.qcow2,size=80   --cdrom ./ubuntu.iso   --os-variant ubuntu24.10   --network network=default   --graphics spice   --boot cdrom,hd --noreboot --noautoconsole```
    * Virtio Win11
        * ```sudo virt-install   --name win11   --memory 8240   --vcpus sockets=1,cores=8,threads=2   --cpu host-passthrough   --os-variant win11   --disk path=/mnt/second/software/vms/win11.qcow2,size=80,format=qcow2,bus=virtio,cache=none,discard=unmap   --cdrom /mnt/second/software/isos/windows11notpm.iso   --disk path=/mnt/second/software/isos/virtio-win-0.1.271.iso,device=cdrom   --network network=default,model=virtio   --machine q35   --boot uefi   --graphics spice,listen=0.0.0.0   --video qxl   --memballoon model=none   --features smm=on   --noreboot --noautoconsole```
    * Virtio Win10
        * ```sudo virt-install   --name win10   --memory 8240   --vcpus sockets=1,cores=8,threads=2   --cpu host-passthrough   --os-variant win10   --disk path=/mnt/second/software/vms/win10.qcow2,size=80,format=qcow2,bus=virtio,cache=none,discard=unmap   --cdrom /mnt/second/software/isos/windows10.iso   --disk path=/mnt/second/software/isos/virtio-win-0.1.271.iso,device=cdrom   --network network=default,model=virtio   --machine q35   --boot uefi   --graphics spice,listen=0.0.0.0   --video qxl   --memballoon model=none   --features smm=on   --noreboot --noautoconsole```

* **Virtiofs not working**
    * Proper way:
```nix
virtualisation.libvirtd = {
  enable = true;
  qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
};
```
    * Hacky way:
        * Install virtiofsd package.
            * Try again
        * ```internal error: virtiofsd binary '/run/current-system/sw/bin/virtiofsd' is not executable```
            * One solution is to add `<binary path="path/to/virtiofsd"/>` to the filesystem section.
            * The quick and dirty way is to use `/run/current-system/sw/bin/virtiofsd`.
        * Try 9p drivers

* **Run AI Models**
    * https://github.com/nixified-ai/flake
    * ```nix run git+https://github.com/nixified-ai/flake.git#textgen-nvidia```
    * ```nix run git+https://github.com/nixified-ai/flake.git#invokeai-nvidia```

* **How to run random binaries**
    * Use nix-ldi
        * Here is a tutorial [link](https://github.com/mcdonc/.nixconfig/blob/master/videos/pydev/script.rst)

* **Python environments**
    * https://ayats.org/blog/nix-workflow/
    * https://www.reddit.com/r/NixOS/comments/1afex3e/setting_up_python_projects/

* **Fastest MP4 splitter**
    * losslesscut-bin

* **Share directories between devices on local network using browser**
    * Fast as f boii but does not work in VM
        * Install `localsend` package
            * webpage: `https://localsend.org/#/download`

    * Requires internet connection and slow
        * ```https://pairdrop.net/```

    * Requires internet connection and slow and cant send big files
        * ```https://www.sharedrop.io/```

* **Nix PR Tracker**
    * https://nixpk.gs/pr-tracker.html

* **QEMU: Huge Pages**
    * To boot.kernelParams:
    ```nix
     "transparent_hugepage=never"
     "hugepagesz=1G"
     "hugepages=8"
    ```
    * Then follow: https://github.com/coolguy1842/dotfiles/blob/afe4c0db337186a04c3bcb27d18809c1f73bcceb/hosts/desktop/vm.nix#L2
    * Ensure memory size is THE SAME as huge page size. E.g. for 8GB:
    ```xml
      <memory unit='KiB'>8388608</memory>
      <currentMemory unit='KiB'>8388608</currentMemory>
      <memoryBacking>
        <hugepages/>
      </memoryBacking>
    ```

* **QEMU: Windows Guest can ping host, but host cannot ping guest on a NATed network**
    * Disable windows firewall.

* **Build in another distro**
    * https://scottworley.com/blog/2023-10-11-Linux-distros-packaging-each-other.html

* **Asus fan control**
    * Modify here:
        * ```cd /sys/devices/platform/asus-nb-wmi```
            * fan-turbo
                * ```sudo sh -c "echo 1 >>  fan_boost_mode"; sudo sh -c "echo 1 >> throttle_thermal_policy"```
            * fan-performance
                * ```sudo sh -c "echo 0 >>  fan_boost_mode"; sudo sh -c "echo 0 >> throttle_thermal_policy"```
            * fan-silent
                * ```sudo sh -c "echo 2 >>  fan_boost_mode"; sudo sh -c "echo 2 >> throttle_thermal_policy"```

* **Install Vivado**
    * Dont. Use a VM.
      * ```sudo apt install libtinfo5```
      * Install cable drivers in a VM
        * ```cd /tools/Xilinx/Vivado/2024.1/data/xicom/cable_drivers/lin64/install_script/install_drivers```
        * ```sudo ./install_drivers```

* **Claudflare Warp**
    * ```NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#cloudflare-warp```
    * ```sudo warp-svc```
    * ```warp-cli registration new```
    * ```warp-cli connect```
    * Check:
        * ```https://www.whatismyip.com```

* **cli overrides**
    * ```NIXPKGS_ALLOW_UNFREE=1  nix run --impure --expr 'with import <nixpkgs> {}; application_name.override { cublasSupport = true; }'```

* **Take out the trash**
    * ```nix-collect-garbage -d```
    * NEVER DO THIS!
        * ```rm /nix/var/nix/gcroots/auto/*```
        * After removing these, home-manager itself started to get garbage collected.

* **Create nixos bootable usb drive**
    * ```cp nixos.iso /dev/sdX```

* **Run docker via nix-shell**
    * nix-shell -p docker
    * sudo dockerd
    * After u are done, ctrl+c

* **Distributing a nix built package to non nix users**
    * Not tested:
        * Build a docker/OCI image, with a docker file
            * https://mitchellh.com/writing/nix-with-dockerfiles
        * Build docker/OCI image, straight from nix
            * https://discourse.nixos.org/t/how-do-i-build-a-binary-on-nixos-that-i-can-run-on-other-distros/11230/14
            * https://nix.dev/tutorials/nixos/building-and-running-docker-images.html
            * https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools
        * Use flatpak / appimage
            * https://github.com/ralismark/nix-appimage 

* **Remove default file associations**
    * xdgmime is already read only so look inside ```.local/share/applications/``` and remove annoying entries.

* **Share internet over usb/ethernet**
    * Network manager > add new connection > ipv4 > shared to other computers
    * To add static IP:
        * Addresses(optional) > Add > "Address=192.168.2.100 Netmask:24 Gateaway:192.168.2.1"

* **Lock a terminal session**
    * Add console lock screen to headless server nixos: ❯ nix run nixpkgs#vlock

* **Nix package versions**
    * Find all versions of a package that were available in a channel and the revision you can download it from.
    * https://lazamar.co.uk/nix-versions/?channel=nixpkgs-unstable&package=helix
