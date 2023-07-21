# dotfiles

# Installation
* Download Arch Linux ISO, boot from it.
* Connect to wifi using iwctl
* `archinstall`
  * profile -> desktop -> sway.
    * Propriatery Nvidia Drivers
  * audio -> pipewire.
  * Configure network -> Use NetworkManager.
  *  Reboot & and login as the user you created.
* ```wget https://raw.github.com/nwg-piotr/nwg-shell/main/install/arch.sh && chmod u+x arch.sh && ./arch.sh && rm arch.sh```
* Hyprland -> yes
* Reboot
* `nwg-shell-config-hyprland` -> backup -> restore -> dotfiles/config/nwg
* Run `install_bunch.sh`
* Reboot
* Gnome Disks
  * Mount external partitions
    * all by label
* Edit firefox settings
  * Settings > General > Startup > Open previous windows and tabs > True
  * Go to the `about:config` URL
    * Set `toolkit.legacyUserProfileCustomizations.stylesheets` to true
    * Set `browser.compactmode.show` to true
    * Set `browser.startup.preXulSkeletonUI` to true
    * Set `browser.sessionstore.restore_pinned_tabs_on_demand` to true
  * Enable compact mode
    * Customize Toolbar > Density > Compact
  * Import Sidebery data

