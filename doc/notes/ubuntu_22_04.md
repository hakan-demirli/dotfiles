* **Alternative to green-tunnel**
	* ```https://github.com/xvzc/SpoofDPI```

* **How to connect to usb tethering**
    * ```sudo nano /etc/netplan/config.yaml```
    * Paste the following:
        ```
            network:
                version: 2
                renderer: networkd
                ethernets:
                    usb0:
                        dhcp4: true
                        dhcp6: false
                        optional: true
        ```

* **Install Display Manager to Ubuntu Server**
    * ```sudo apt-get install tasksel -y```
    * ```sudo tasksel```
        * Follow the prompts

* **Nemo Could not acquire name on session bus. Core Dump**
    * Log out.
    * Click user icon
    * Select the cogwheel on the bottom right.
    * Use ```Ubuntu Xorg``` instead of ```Ubuntu```.

* **Cursor is white blocky/square**
    * Install new cursor themes
        * `sudo apt install adwaita-icon-theme-full`
        * `sudo apt install yaru-theme-gtk yaru-theme-sound yaru-theme-gnome-shell yaru-theme-icon yaru-theme-unity`
    * Select it from gnome tweaks

* **Can't install Gnome extensions from gnome website**
    * Install them through the app
        * Install the app
        ```bash
        sudo apt-get update
        sudo apt-get upgrade
        sudo apt install gnome-shell-extension-manager
        ```
    * Open it: BLue puzzle icon
        * Browse -> install

* **Bring back minimze and maximize buttons**
    * Open gnome tweaks.
    * Search for minimize
    * Enable all

* **Kolourpaint missing icons**
    * Install breeze icon theme
        * ```sudo apt install breeze```

* **How to share folder KVM/QEMU Virt-Manager**
    * Windows guest:
        * [Virtiofs](https://github.com/virtio-win/kvm-guest-drivers-windows/wiki/VirtIO-FS:-Shared-file-system)
            * Open the Virtual Machine Manager and enable XML editing.
                * Edit -> Preferences -> Enable XML
            * Enable shared memory
            * Add Hardware -> Filesystem
                * Set source path
                    * Select the directory you want to share.
                        * Browse -> Browse Local
                * Set target path
                    * I name it `shared`
                * Driver -> virtiofs
                * Be sure the xml has something similar:
                    * ```<driver type="virtiofs" queue="1024"/>```
            * Download and install [WinFSP](https://github.com/winfsp/winfsp/releases) with at least "Core" feature enabled.
            * Install VirtIO-FS driver and service from [VirtIO-Win package](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md).
            * Open command promprt as admin
            * Setup VirtIO-FS service by running ```sc create VirtioFsSvc binPath="<path to the binary>\virtiofs.exe" start=auto depend=VirtioFsDrv```. Don't forget to appropriately set binPath.
            * You can immediately start the service by running ```sc start VirtioFsSvc```.
            * The letter will be `Z`. Be sure it is available.
    * Linux guest:
        * Enable shared memory
        * Add Hardware -> Filesystem
            * Set source path
                * Select the directory you want to share.
                    * Browse -> Browse Local
            * Set target path
                * I name it `shared`
            * Driver -> virtiofs
        * In the VM:
            * mkdir ~/shared
            * sudo mount -t virtiofs shared /home/emre/shared


* **How to mount multiple folders QEMU-KVM Virtiofs**
    * The tutorials didn't work.
    * Mount /mnt/ folder. Since all drives are there. You can access them all.

* **The specified movie could not be found.**
    * This is a known bug.
        * ```sudo apt remove gstreamer1.0-vaapi```

* **Video acceleration not working**
    * Yeah, me too. :(

* **Default Video Player (Totem) throws error on wayland**
    * Error code: ```(python3:3933): CRITICAL **: 16:37:50.961: Failed to flush Wayland connection```
        * No solution afaik.
    * Use another video player:
        * Remove `totem`. No need for a broken player
            * ```sudo apt-get purge totem totem-plugins```
        * mplayer:
            * Console based player. No GUI. Only shortcuts. I don't like it.
        * VLC
            * Works.

* **Limit CPU Frequency**
    * ```sudo apt install cpupower-gui```

* **QT can't find debugger**
    * ```sudo apt install gdb```
        * reboot

* **How do I add locale to ubuntu server?**
    * Check which locales are supported:
        * ```locale -a```
    * Add the locales you want (for example GB):
        * ```sudo locale-gen en_GB```
        * ```sudo locale-gen en_GB.UTF-8```
    * ```sudo update-locale```

* **How to use modelsim 32bits with cocotb**
    * Install miniconda
        * ```https://docs.conda.io/en/latest/miniconda.html#linux-installers```
    * Add conda to path
        * ```export PATH=/home/emre/miniconda3/bin:$PATH```
    * ```conda config --set auto_activate_base False```
    * ```conda create -n py3_32```
    * ```conda activate py3_32```
    * ```conda config --env --set subdir linux-32```
    * ```conda install python=3 gxx_linux-32```
    * ```sudo dpkg --add-architecture i386```
    * ```sudo dpkg --add-architecture i386```
    * ```sudo apt-get update```
    * ```sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git xz-utils wget curl llvm```
    * ```sudo apt-get install -y make gcc-multilib g++-multilib libssl-dev:i386 zlib1g-dev:i386 libbz2-dev:i386 libreadline-dev:i386 libsqlite3-dev:i386 libncurses5-dev:i386 libncursesw5-dev:i386 libffi-dev:i386 liblzma-dev:i386```
    * ```pip3 install tk-tools```
    * ```conda install python=3 gxx_linux-32```
    * ```conda activate py3_32```
    * ```python3 -m pip install cocotb```
    * continue

* **Increase open file limit**
    * ```sudo sysctl -w fs.file-max=100000```
    * ```sudo nano  /etc/sysctl.conf```
        * ```fs.file-max = 100000```
    * ```sudo sysctl -p```
    * ```ulimit -n```
    * ```ulimit -n 10000```

* **libffi.so.7: cannot open shared object file: No such file or directory**
    * ```wget http://es.archive.ubuntu.com/ubuntu/pool/main/libf/libffi/libffi7_3.3-4_amd64.deb```
    * ```sudo apt install ./libffi7_3.3-4_amd64.deb```

* **How to connect to a wifi using qr code**
    * ```sudo apt-get install -y zbar-tools```
    * ```git clone https://github.com/kokoye2007/wifi-qr```
    * ```./wifi-qr -g```

* **How to Install Nerd Font**
    1. Download JetBrainsMono [Nerd Font](http://nerdfonts.com/)
    2. Unzip and copy to `~/.fonts`
    3. Run the command `fc-cache -fv` to manually rebuild the font cache

* **NVCHAD**
    * pip install pyright

* **How to install eww**
    * Install dependencies:
      * ```I installedlibqt5glib-2.0-0 libspice-client-glib-2.0-8 libspice-client-glib-2.0-dev libgdk-pixbuf-2.0-dev libgdk-pixbuf2.0-dev librust-atk-dev librust-atk-sys-dev libcairo-gobject2 libcairo-gobject-perl librust-cairo-rs-dev librust-cairo-sys-rs-dev librust-pangocairo-dev librust-pangocairo-sys-dev librust-gdk-pixbuf-dev librust-gdk-pixbuf-sys-dev librust-gdk-sys-dev these packages and it worked.```
    * Clone eww:
      * ```git clone https://github.com/elkowar/eww```
      * ```cd eww```
    * ```sudo snap install rustup --classic```
    * ```cargo build --release --no-default-features --features=wayland```

* **How to edit gnome default shortcuts**
    * sudo apt install dconf-editor

* **How to install gem5**
    * ```sudo apt install build-essential git m4 scons zlib1g zlib1g-dev libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev python3-dev libboost-all-dev pkg-config```
    * ```python3 -m pip install -r requirements.txt```

* **Tiling manager for gnome**
    * https://github.com/forge-ext/forge

* **WINE error "001e:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\wineusb": c0000142"**
    * ERROR: :err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\wineusb": c0000142
        * Ensure lutris can see your nvidia gpu
        * If yes
            * delete .wine folder

* **Enable Gnome focus follows mouse**
    * ```sudo apt install gnome-tweaks```
    * Launch Tweaks and go to the Windows section.
        *  Select "Sloppy" or "Secondary-Click" under Window Focus.

* **wine: Could not find Wine Gecko. HTML rendering will be disabled.**
    * Download https://wiki.winehq.org/Gecko msi file
        * Then put them into the ~/.cache/wine/
    * Maybe delete .wine if fails

