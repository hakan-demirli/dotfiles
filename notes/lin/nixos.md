* **What is configuration.nix file?**
    * It's default location is: ```/etc/nixos/configuration.nix```
    * It controls the OS configuration. You want to install a package you modify it.
    * It is a bad practice to leave it in it's default location. Use flakes instead.

* **Where to find packages**
    * https://search.nixos.org/packages

* **Install git**
    * Temporarily:
        * ```nix shell nixpkgs#git```
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
    * ```internal error: virtiofsd binary '/run/current-system/sw/bin/virtiofsd' is not executable. This happened because Qemu stopped bundling virtiofsd. I added it to system config to make it appear on that path again and encountered an error operation failed: Unable to find a satisfying virtiofsd```
    * No solution.
    * try 9p drivers