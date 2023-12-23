* **How to install and use home-manager**
  * Install nix:
    * Distro dependent.
  * If no config exists:
    * Generate and activate a basic home-manager configuration:
      * ```nix run home-manager/master -- init --switch```
  * Switch to home-manager config
    * ```nix run home-manager/master -- switch```

* ```nix run home-manager/master -- switch --flake ~/.config/home-manager#emre```

* ```nix run home-manager/master -- switch --flake ~/.config/home-manager#emre -v```
