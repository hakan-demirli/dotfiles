
# Install Aylur/AGS

## Installation
* Download Arch Linux ISO, boot from it.
* Connect to wifi using iwctl
* `archinstall`
  * profile -> desktop -> minimal.
    * Propriatery Nvidia Drivers
  * audio -> pipewire.
  * Configure network -> Use NetworkManager.
  *  Reboot & and login as the user you created.
* ?
* ?
* [Mount Disks](#mount-disks)
* [Apply Custom Firefox CSS](#edit-firefox-settings)





-----------------------------------------


# Install nwg-shell

## Installation
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
* `nwg-shell-config-hyprland` -> backup -> restore -> dotfiles/.config/nwg
* Run `install_bunch.sh`
* Reboot
* [Mount Disks](#mount-disks)
* [Apply Custom Firefox CSS](#edit-firefox-settings)


-----------------------------------------
-----------------------------------------
-----------------------------------------

### Edit firefox settings
* Settings > General > Startup > Open previous windows and tabs > True
* Go to the `about:config` URL
  * Set `toolkit.legacyUserProfileCustomizations.stylesheets` to true
  * Set `browser.compactmode.show` to true
  * Set `browser.startup.preXulSkeletonUI` to false
  * Set `browser.sessionstore.restore_pinned_tabs_on_demand` to true
  * Set `menuAccessKeyFocuses` to false
* Enable compact mode
  * Customize Toolbar > Density > Compact
* Import Sidebery data

### Mount disks
* Gnome Disks
  * Mount external partitions
    * all by label

