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
