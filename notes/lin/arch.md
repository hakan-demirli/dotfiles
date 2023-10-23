* **Convert pip package to PKGBUILD**
    * yay -S pip2pkgbuild

* **Create swap**
    * Check if swap file exists:
        * ```sudo swapon -s```
    * Close all active swap files:
        * ```sudo swapoff -a```
    * Create a swap file bigger than the ram
        ```
        sudo dd if=/dev/zero of=/swapfile bs=1G count=30 status=progress
        sudo mkswap /swapfile
        sudo chmod 600 /swapfile
        sudo swapon /swapfile
        ```
    * Make it persistent:
        * Backup fstab file:
            * ```sudo cp /etc/fstab /etc/fstab.backup```
        * Edit fstab file:
            * ```echo '/swapfile none    swap    defaults 0 0' | sudo tee -a /etc/fstab```
        * Check for errors:
            * ```sudo mount -a```
        * Delete backup if there are no errors:
            * ```sudo rm /etc/fstab.backup```

* **Enable Hibernation**
    * May not work if Grub remember last booted is set
    * Auto setup
        * Create a swapfile bigger than your ram.
        * Use hibernator script in dotfiles/scripts/lin directory

    * Manual, may not work
        * [tutorial](https://confluence.jaytaala.com/display/TKB/Use+a+swap+file+and+enable+hibernation+on+Arch+Linux+-+including+on+a+LUKS+root+partition#UseaswapfileandenablehibernationonArchLinuxincludingonaLUKSrootpartition-Enablehibernation)
        * Create a swap file bigger than your RAM
        * Update Grub:
            * Backup Grub
                * ```sudo cp /etc/default/grub /etc/default/grub.backup```
            * Find device UUID for root partition (non-LUKS)
                * Find what is mounted on `/`
                    * `df`
                * Find the uuid of the disk mounted on /
                    * ```sudo blkid```
            * Find physical offset of swapfile
                * ```sudo filefrag -v /swapfile```
                * First value of the physical offset field. Each field/column consists of two sub columns. Be careful.
            * Edit grub file
                * ```sudo vim /etc/default/grub```
                * We want to find the line starting with GRUB_CMDLINE_LINUX_DEFAULT and append following following bits of information we got previously.
                    * ```GRUB_CMDLINE_LINUX_DEFAULT="quiet resume=UUID=f68ed3c5-da10-4288-890f-b83d8763e85e resume_offset=45731840"```
                * ```sudo grub-mkconfig -o /boot/grub/grub.cfg```
                * ```reboot```

        * ```systemctl hibernate```

* **Use woeusb without gui**
    * ```sudo woeusb /mnt/second/software/isos/Win10_22H2_English_x64v1.iso --device /dev/sdb```

* **Set theme preference for gnome**
    * ```gsettings set org.gnome.desktop.interface color-scheme prefer-dark```

* **Gnome disks alternative**
    * Gparted

* **Kolourpaint alternative**
    * Drawing

* **How to downgrade a package**
    * ```yay -S downgrade```
    * ```sudo downgrade <package_name>```

* **Change default application using xdg-mime**
    * ```xdg-mime query filetype test.md```
    * ```xdg-mime query default image/png```
    * ```xdg-mime default helix.desktop image/png```

* **Grub remember last booted**
    * Uncomment these lines in /etc/default/grub
        * GRUB_DEFAULT=saved
        * GRUB_SAVEDEFAULT=true

* **Add windows to grub menu**
    * GUI tool:
        * Grub Customizer
            * Can't add automatically.
    * Manual way:
        * `sudo os-prober` Find disk name
        * `lsblk` list all disks disks
        * `sudo grub-probe -t fs_uuid -d /dev/sda1` get id uuid of efi
        * `sudo helix /etc/grub.d/40_custom` add menuentry. Replace XXX with uuid.
            ```
            menuentry "Windows 10" {
                savedefault
                insmod part_gpt
                insmod fat
                insmod search_fs_uuid
                insmod chain
                search --fs-uuid --no-floppy --set=root XXXXXXXXX
                chainloader (${root})/efi/Microsoft/Boot/bootmgfw.efi
            }
            ```
        * `sudo chmod +x /etc/grub.d/40_custom` Set permissions.
        * `sudo grub-mkconfig -o /boot/grub/grub.cfg` regen grub.cfg
        * reboot.

* **How to connect to wifi (live usb)**
    * ```iwctl```
    * ```device list```
    * ```station <device> scan```
    * ```station <device> get-networks```
    * ```station <device> connect <SSID>```

* **How to install arch linux (live usb)**
    * ```archinstall```
    * Set drive and partition
        * Do not create a separate enviroment for home!
        * It gives 20GB for root. We don't want that.
    * Add user
    * Set profile for desktop enviroment (minimal)
    * Set Audio (pipewire)
    * Set network manager
    * Install.

* **How to install yay**
    * ```pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si```

* **How to connect to wifi**
    * nm-connection-editor

* **Dope dotfiles**
    * ```git clone https://github.com/Aylur/dotfiles.git```

* **"[libseat/backend/seatd.c:70] Could not connect to socket /run/seatd.sock: no such file or directory" after updating wlroots, Sway and libseat on Arch**
    * DIDN'T WORK FOR HYPRLAND
    * add this to `/etc/environment`
        * ```LIBSEAT_BACKEND=logind```

* **Launch Graphical Applicaiton with sudo on Wayland**
    * Situation:
        * https://discussion.fedoraproject.org/t/graphical-applications-cant-be-run-as-root-in-wayland/75412
    * For example `gnome-disks`
        * ```sudo --preserve-env=XDG_RUNTIME_DIR,WAYLAND_DISPLAY gnome-disks```

* **Mount NTFS and EXT4 disks**
    * ```yay -S ntfs-3g```

* **Nemo missing right click options**
    * ```yay -S nemo-fileroller```
    * ```yay -S unzip```

* **How to change GTK Theme**
    * ```gsettings get org.gnome.desktop.interface gtk-theme```q
    * ```yay -S arc-gtk-theme```
    * ```gsettings set org.gnome.desktop.interface gtk-theme Arc-Dark```

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
    * pacman -Syu
    * yay

* **Hyrpland list all windows**
    * ```hyprctl clients```

* **Kill an app**
    * ```killall -SIGUSR2 waybar```

* **Print freq of each core**
    * ```grep "MHz" /proc/cpuinfo | awk '{print "Core", NR-1, ":", $4, "MHz"}'```

* **Blueberry can not scan**
    * Install blueman
        * yay - S blueman
    * Run manager
        * blueman-manager

* **Nix occupy too much space**
    * ```nix-collect-garbage -d ```

* **Searching and installing old versions of Nix packages**
    * [This site.](https://lazamar.co.uk/nix-versions/)
    * Click to hash it will show how to use it.
    * But I prefer adding the url as a new package like this:
        * ```inputs.protobuf_pin.url = "github:NixOS/nixpkgs/976fa3369d722e76f37c77493d99829540d43845";```
    * Then you can do this:
        * ```pkgs_for_protobuf = protobuf_pin.legacyPackages.${system};```
        * ```pkgs_for_protobuf.protobuf```

* **How to get sha256 of a nixpkg version**
    * ```nix-prefetch-url --unpack "https://github.com/NixOS/nixpkgs/archive/976fa3369d722e76f37c77493d99829540d43845.tar.gz```
    * This will print it

* **KDE How to remove volume/sound icon from firefox**
    * It is Icons-Only-Task-Manager widget.
        * Settingsof the widget -> mark ...

* **How to check power consumption**
    * ```sudo pacman -S powertop```

* **How to use multiple cores for AUR packages**
    * /etc/makepkg.conf:
        * uncomment the following line
            * `MAKEFLAGS="-j4"`
        * Change it to `MAKEFLAGS="-j$(nproc)"`

* **How to install gem5**
    * Install dependencies
        ```
        sudo pacman -S --noconfirm --needed git
        sudo pacman -S --noconfirm --needed gcc
        sudo pacman -S --noconfirm --needed clang
        sudo pacman -S --noconfirm --needed scons
        sudo pacman -S --noconfirm --needed python
        sudo pacman -S --noconfirm --needed protobuf
        sudo pacman -S --noconfirm --needed boost

        sudo pacman -S --noconfirm --needed base-devel
        sudo pacman -S --noconfirm --needed m4
        sudo pacman -S --noconfirm --needed zlib
        sudo pacman -S --noconfirm --needed gperftools
        sudo pacman -S --noconfirm --needed pkg-config

        echo "you must downgrade protobuf to 21.12.2. Otherwise: DSO missing from command line."
        ```

* **How to install Xschem**
    * ```yay -S --noconfirm --answerdiff=None xschem```
    * ```yay -S --noconfirm --answerdiff=None gaw-xschem-git```
    * ```sudo pacman -S --noconfirm --needed xterm```

* **How to find deb/ubuntu equivalent of package**
    * Look up the package and its filelist on Debian's package archive.
        * For example, https://packages.debian.org/bullseye/amd64/lib32z1-dev/filelist
        * Note any files that are in directories specified by the linux filesystem hierarchy.
            * For example, I pick /usr/lib32/libz.so
    * Search for a file using pacman or pkgfile.
        * For example, ```pkgfile -s /usr/lib/32/libz.so```
            * multilib/lib32-zlib
    * Therefore the file is in lib32-zlib

* **Reproducible Shell environments via Nix Flakes**
    * Install nix
    * Activate flakes:
        * ```~/.config/nix/nix.conf:```
            * ```experimental-features = nix-command flakes```
    * Create a flake.
    * ```nix develop```
    * Now you are in the shell which has the packages.

* **Create direnv flake project**
    * Install nix
    * Activate flakes:
        * ```~/.config/nix/nix.conf:```
            * ```experimental-features = nix-command flakes```
    * Install direnv
        * Use your default package manager: pacman
        * ```echo 'eval "$(direnv hook bash)"' >> ~/.bashrc```
    * Create a flake template
        * ```nix flake new -t github:nix-community/nix-direnv <desired output path>```
        * ```direnv allow```

* **Nix undefined variable on python pip package**
    * https://stackoverflow.com/questions/76540098/how-to-create-a-nix-project-with-the-python-package-streamlit

* **Enable tor as a proxy**
    * ```sudo pacman -S tor```
    * ```sudo systemctl start tor.service```
    * ```sudo systemctl stop tor.service```
    * From now on do not use systemctl. Use `sudo tor` when you need it.
    * Firefox:
        * In Settings > Search network > Manual proxy configuration 
        * Enter SOCKS host: `localhost` with port `9050` (SOCKS v5).
        * Select Proxy DNS when using SOCKS v5.

* **Enable ECH on Firefox**
    * In `about:config`
        * true: `network.dns.use_https_rr_as_altsvc`
        * true: `network.dns.echconfig.enabled`
    * Enable DoH:
        * Search 'doh' on firefox settings
        * 'Enable Secure DNS using'
            * 'Increased Protection' or 'Max Protection'
    * Check if it works from here:
        * https://www.cloudflare.com/ssl/encrypted-sni/#results

* **Clean Home Directory**
    * This shows the folders that can be moved:
        * https://wiki.archlinux.org/title/XDG_Base_Directory
    * This automatically scans and shows
        * ```yay -S xdg-ninja```

# LATER
OpenSnitch - is a GNU/Linux interactive application firewall

RustDesk   – The Open Source Remote Desktop Access Software

Frog       - Extract text from images

cassowary  - Run Windows Applications on Linux as if they are native. WSL like.

