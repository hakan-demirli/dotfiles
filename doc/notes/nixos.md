* **Using nixGL to fix OpenGL applications on non-NixOS distributions**
    * https://pmiddend.github.io/posts/nixgl-on-ubuntu/

* **Get home-manager generated files/outputs without activating**
    * `home-manager build --flake ~/Desktop/dotfiles/#emre`

* **List exported binaries**
    * ls -al $(nix-build --no-out-link '<nixpkgs>' -A gcc)/bin/`

* **Restart touchpad driver**
    * Find kernel module responsible for the touchpad:
        * `lsmod`
    * Kill it:
        * `sudo modprobe -r hid_multitouch`
    * Restart it:
        * `sudo modprobe hid_multitouch`

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

* **Virtiofs not working**
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
