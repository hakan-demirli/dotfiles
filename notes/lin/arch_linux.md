https://confluence.jaytaala.com/display/TKB/Use+a+swap+file+and+enable+hibernation+on+Arch+Linux+-+including+on+a+LUKS+root+partition#UseaswapfileandenablehibernationonArchLinuxincludingonaLUKSrootpartition-Enablehibernation

```systemctl hibernate```


sudo woeusb /mnt/second/software/isos/Win10_22H2_English_x64v1.iso --device /dev/sdb


sudo woeusb /mnt/second/software/isos/Win10_22H2_English_x64v1.iso --device /dev/sdb




* Arch Linux System Freeze on Startup
    * try setting media.rdd-ffmpeg.enabled to false
    *
* Gparted is a gtk based disk tool. Better than gnome disks etc.
* "Drawing" is an alternative to kolourpaint on gnome.


# Live USB
* **How to connect to wifi**
	* ```iwctl```
	* ```device list```
	* ```station <device> scan```
	* ```station <device> get-networks```
	* ```station <device> connect <SSID>```

* **How to install arch linux**
	* ```archinstall```
	* Set drive and partition
		* Do not create a separate enviroment for home!
		* It gives 20GB for root. We don't want that.
	* Add user
	* Set profile for desktop enviroment (minimal)
	* Set Audio (pipewire)
	* Set network manager
	* Install.

# Installed
* **How to install yay**
	* ```pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si```

* **How to connect to wifi**
	* nm-connection-editor

* **How to install hyprland and eww**
	* ```yay -S --noconfirm --answerdiff=None hyprland eww-wayland ttf-ubuntu-nerd socat jq acpi inotify-tools bluez pavucontrol brightnessctl playerctl nm-connection-editor imagemagick gjs gnome-bluetooth-3.0 upower networkmanager gtk3 wl-gammactl wlsunset wl-clipboard hyprpicker hyprshot blueberry polkit-gnome kitty neovim```

* **Dope hyprland and eww configs**
	* ```   git clone https://github.com/Aylur/dotfiles.git
		cp -r dotfiles/.config/eww ~/.config/eww
		cp -r dotfiles/.config/hypr ~/.config/hypr
		mv ~/.config/hypr/_hyprland.conf ~/.config/hypr/hyprland.conf```
	* ```Hyprland```
	* ```gtk-update-icon-cache```



**"[libseat/backend/seatd.c:70] Could not connect to socket /run/seatd.sock: no such file or directory" after updating wlroots, Sway and libseat on Arch**
	* DIDN'T WORK FOR HYPRLAND
	* add this to `/etc/environment`
		* ```LIBSEAT_BACKEND=logind```

**Launch Graphical Applicaiton with sudo on Wayland**
    * Situation:
    	* https://discussion.fedoraproject.org/t/graphical-applications-cant-be-run-as-root-in-wayland/75412
    * For example `gnome-disks`
        * ```sudo --preserve-env=XDG_RUNTIME_DIR,WAYLAND_DISPLAY gnome-disks```

**Mount NTFS and EXT4 disks**
    * ```yay -S ntfs-3g```

**Connect to wifi**
    * Install iwctl if it is not installed
        * ```yay -S iwd```
        * ```sudo systemctl start iwd```
    * ```iwctl```
    * ```

* **Nemo missing right click options**
    * ```yay -S nemo-fileroller```
    * ```yay -S unzip```

* **How to change GTK Theme**
    * ```gsettings get org.gnome.desktop.interface gtk-theme```q
    * ```yay -S arc-gtk-theme```
    * ```gsettings set org.gnome.desktop.interface gtk-theme Arc-Dark```

* **Login manager**
	* WORKS
		* ```yay -S swaylock-effects-git```
	* DOES NOT WORK!
		* ```pacman -S gcc make pkgconf scdoc pam wayland gtk3 gtk-layer-shell```
		* ```yay -S gtklock```

    yay -S kolourpaint
    yay -S breeze-icons

    amberol
    # timedatectl set-timezone Asia/Istanbul

    backup kitty, hypr, eww, swaylock, nemo, nvim,
    https://github.com/kovidgoyal/kitty-themes

yay -S zsh



symlik dotfiles

yay -S starship]

pacman -S exa


* **How to change locale**
	* List available locales
		* locale -a
	* Uncomment the one if it is not there
		* /etc/locale.gen
	* Regenerate locales
		* locale-gen
	* Change locale
		* localectl set-locale LANG=en_GB.UTF-8

* **How to make OBS screen capture work**
	* We need screen capture pipewire:
		* yay -S xdg-desktop-portal-hyprland-git


* **Equivalent of sudo apt update/upgrade**
	* yay

* **Hyrpland list all windows**
	* ```hyprctl clients```

# Neovim

% to create file in default file tree
d to create directory
D to delete file

scrcpy yay

yay s vlc

yay s lutris


eww has a log leak. 500GB log file is not acceptable.
link it to dev/null
ln -sf /dev/null ~/.cache/eww_*.log

otf-font-awesome

sudo nmcli device wifi connect <SSID> password <password>

restart waybar
killall waybar
https://github.com/Alexays/Waybar/issues/2177


ln -s ~/dotfiles/dots/eww ~/.config/eww

bluez-utils
modprobe btusb
systemctl start bluetooth.service


* **Blueberry can not scan**
    * Install blueman
        * yay - S blueman
    * Run manager
        * blueman-manager
 hyprctl keyword monitor DP-4,preferred,auto,1,transform,1

yay s cronie

 yay -S noto-fonts-cjk

bind control f to fzf command for zsh shell
bindkey -s '^F' 'fzf^M'

https://github.com/rust-lang/cargo/issues/3381
r


* **KDE How to remove volume/sound icon from firefox**
	* It is Icons-Only-Task-Manager widget.
		* Settingsof the widget -> mark ...





gsettings set org.gnome.desktop.interface color-scheme prefer-dark

gsettings set org.gnome.desktop.interface color-scheme prefer-light


There is a variable in /etc/makepkg.conf which does exactly that for every package: MAKEFLAGS="-j4"
105
User avatar
level 2
ubersketch
·
7 yr. ago
Helpful

Use "-j$(nproc)" to give you the number of cores available to the system. This allows for portability between machines











