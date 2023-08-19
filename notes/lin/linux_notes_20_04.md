* **Update update server list and install upgrades**
    * ```sudo apt update```
    * ```sudo apt upgrade```

* **Add a directory to path**
    * ```export PATH=$PATH:/usr/local/bin```
    * ```export PATH=$PATH:/usr/local/sbin```

* **Set enviroment variable and add it to path**
    * ```export QTDIR=/home/dell/Qt5.9.2/5.9.2/gcc_64```
    * ```export PATH=$QTDIR/bin:$PATH```

* **Set enviroment variable and add it to another path**
    * ```export QTDIR=/home/dell/Qt5.9.2/5.9.2/gcc_64```
    * ```export LD_LIBRARY_PATH=$QTDIR/lib:$LD_LIBRARY_PATH```

* **Check a path variable**
    * ```echo "$WORKSPACE"```

* **How to learn current distro name?**
    * ```uname -a```
    * ```neofetch```

* **Print all users**
    * ```w```

* **Install an app**
    * ```sudo apt-get install [APP_NAME] ```

* **Permanently add enviroment variables**
    * Add the path creating/modifying commands to the end of the .profile file.
    * ```source ~/.profile```

* **Create an application/file/folder shortcut**
    * For an application
      * Open /usr/share/applications
      * Copy the application shortcut to desktop
      * Right click on the shortcut on the desktop and select Allow Launching
    * For Folder/File shortcut
      * Either directly use the terminal to create a symbolic link:
      ```ln -s <complete path to dir> <shortcut save location>```
      * Or open the folder in the file manager (nautilus), navigate to the directory to which you want to create a shortcut to.
      * Right click and select Open in Terminal.
      * For shortcut to current directory, type and execute
      ```ln -s $PWD ~/Desktop/```
      * For shortcut to a file/folder inside the current directory, type and execute:
      ```ln -s $PWD/filename ~/Desktop/```
      * or
      ```ln -s $PWD/dirname ~/Desktop/```

* **Search installed apps with certain name**
    * ```apt list --installed | grep "<app_name>"```

* **How to install riscv-gnu-toolchain without compiling**
    * [This guy release it.](https://github.com/stnolting/riscv-gcc-prebuilt)

* **Run script**
    * Be sure it has the right permissions if not use:
    ```chmod +x script-name-here.sh```
    * Run the script by using:
    ```./script_name.sh```
    * or
    ```sh script-name-here.sh```
    * or
    ```bash script-name-here.sh```

* **Run app from terminal**
    * ```app_name & disown # run in background and detach from terminal```

* **SSH connection**
    * ```sudo apt-get install openssh-server```
    * ```sudo systemctl enable ssh```
    * ```sudo systemctl start ssh```
    * ```ssh root@192.168.137.90```

* **Copy File over ssh**
    * ```scp <source> <destination>```
    * ```scp  D:\ssh\camera_in.tar root@192.168.137.237:~/```

* **Install OpenCV**
    * Precompiled binaries, but they are old
        * ```sudo apt-get install libopencv-dev```
    * Build from source
        * https://github.com/milq/milq

* **Run command at login**
    * Add the command to the end of ~/.profile

* **Run command every time a bash shell is started**
    * Add the command to the end of ~/.bashrc

* **Run command every boot with root privilages**
    * Create a file ==> /etc/rc.local
    * Add commands for example update:
    ```bash
        #!/bin/sh -e
        apt-get update
        exit 0
    ```
    * ```sudo chmod +x /etc/rc.local```
    * Reboot

* **Fix numlock (Cinnamon,PopOS)**
    * Control Center -> Keyboard -> Layouts -> Options -> Miscellaneous Compatibility Options -> Shift with Numeric Keypads works as in MS Windows
    * ```  setxkbmap -option 'numpad:microsoft' ```

* **QT Creator/VS Code can't parse cpp files**
    * Install clang 8 and set it as alternative
      ```bash
         sudo apt install clang-8
         sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-8 100
         sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-8 100
      ```
    * [SOURCE](https://askubuntu.com/questions/1232969/qtcreator-not-recognizing-linked-libraries-after-upgrading-ubuntu-to-20-04)

* **(opencvtest:1927): Gtk-WARNING **: cannot open display. OpenCV/USB Webcam**
    * ```export DISPLAY=:0```

* **Increase Swap Size**
    * Be sure that swapfile you create has the same name as the existing one.
        * Otherwise you have to add it to fstab manually to make it permanent.
    * Turn swap off
        ```sudo swapoff -a```
    * Create an empty swapfile
        * Note that "1G" is basically just the unit and count is an integer. Together, they define the size. In this case 8GB.
        ```sudo dd if=/dev/zero of=/swapfile bs=1G count=8```
        * Also, don't use `fallocate` command. `dd` is the way.
    * Set the correct permissions
        ```sudo chmod 0600 /swapfile```
    * Set up a Linux swap area
        ```sudo mkswap /swapfile```
    * Turn the swap on
        ```sudo swapon /swapfile```
    * If the swap file is new make it permanent
        * ```sudo nano /etc/fstab```
        * ```/swapfile none swap sw 0 0```

* **Install Wine**
    * Install Lutris and use it to install wine
    * Direct install
        1. Update and Upgrade Linux Mint 20.3
            * ``` sudo apt update```
            * ``` sudo apt upgrade```
        2. Downloading WineHQ.gpg Key
            * ```wget -nc https://dl.winehq.org/wine-builds/winehq.key```
        3. Adding WineHQ.gpg.key to /etc/apt/trusted.gpg.d/
            * ```sudo -H gpg -o /etc/apt/trusted.gpg.d/winehq.key.gpg --dearmor winehq.key```
        4. Adding WineHQ Repository
            * ```sudo add-apt-repository 'deb https://dl.winehq.org/wine-builds/ubuntu focal main'```
        5. Updating Linux Mint 20.3
            * ```sudo apt update```
        6. Installing Wine Devel [ Wine 7.0 ]
            * ```sudo apt install --install-recommends winehq-devel```
        7. Checking Wine Version
            * ```wine --version```
        8. Run clock demo
            * ```wine clock```

* **Intel GPU Monitor**
    * ```sudo apt install intel-gpu-tools```
    * ```sudo intel_gpu_top```

* **Nvidia GPU Monitor**
    * Official Nvidia Prime Monitor
        * ```watch -n0.1 nvidia-smi```
            * `0.1` is the refresh period
    * Third Party Monitor
        * ```sudo apt install nvtop```

* **NVIDIA X Server GUI Intel(power save) mode unavailable/grayed out**
    * ```sudo prime-select intel```
        * Nvidia will be disabled. Change profile to `on-demand` and reboot to enable it again.

* **How to launch an app with a discrete GPU (AMD/Nvidia/ARC/offload)**
    * Use Lutris
    * Use Prime run
        * Create a file ~/bin/prime-run:
            ```bash
            #!/bin/bash
            export __NV_PRIME_RENDER_OFFLOAD=1
            export __GLX_VENDOR_LIBRARY_NAME=nvidia
            export __VK_LAYER_NV_optimus=NVIDIA_only
            export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
            exec "$@"
            ```
        * ```chmod +x "~/bin/prime-run```
        * Re-open your terminal
        [SOURCE](https://askubuntu.com/questions/1364762/prime-run-command-not-found)

* **How to launch a flatpack app with a discrete GPU (AMD/Nvidia/ARC/offload)**
    * Install Flatseal
    * Add this as an Enviroment variable:
    ``` __NV_PRIME_RENDER_OFFLOAD=1 ```
    * If it is still not working:
        * Choose high performance from Nvidia Xserver settings.

* **Run an app without sudo password**
    * [?????????????]

* **How to add CalDAV/WebDAV/ICS server to a calendar app(Thunderbird/gnome/evolution)?**
    * You can't. They are all really buggy. Don't even try.
    * Just login to gnome/cinnamon via your Google account.

* **Change the First Day of the Week (Calendar/Gnome/Date)**
    * Open this file: `/usr/share/i18n/locales/en_US`
        * Add `first_weekday 2` between LC_TIME LC_TIME-END
        * ```sudo locale-gen```
    * Or change your local settings to United Kingdom

* **QT Performance Analysis on Linux**
    * Edit this file to 0: `/proc/sys/kernel/kptr_restrict`
        * The default was 1.
    * Edit this file to -1: `/proc/sys/kernel/perf_event_paranoid`
        * The default was 4.

* **Required Libraries for Modelsim Starter Edition**
    * ```sudo apt-get install lib32z1 lib32stdc++6 lib32gcc1 expat:i386 fontconfig:i386 libfreetype6:i386 libexpat1:i386 libc6:i386 libgtk-3-0:i386 libcanberra0:i386 libpng16-16:i386 libice6:i386 libsm6:i386 libncurses5:i386 zlib1g:i386 libx11-6:i386 libxau6:i386 libxdmcp6:i386 libxext6:i386 libxft2:i386 libxrender1:i386 libxt6:i386 libxtst6:i386```

* **Put every dependency into a file (QT/GCC/C++/Compile/libs/static/dynamic)**
    * https://stackoverflow.com/questions/9578843/how-to-statically-link-against-opencv-in-qt-project

* **Touchpad Control (Gesture/Synaptic/Elan)**
    * https://github.com/JoseExposito/touchegg
        * https://github.com/JoseExposito/touche
            * ```sudo apt-get install wmctrl xdotool```
            * ```sudo apt-get install libinput-tools```
            * reboot
            * 4 Finger Swipe Left -> Keyboard Shortcut -> Ctrl-Alt-Down
            * 4 Finger Swipe Right -> Keyboard Shortcut -> Ctrl-Alt-Up
            * 4 Finger Swipe Up -> Keyboard Shortcut -> Super_L-S

* **Install Gnome Shell on Linux Mint**
    * Then remove following folders:
        * .config/cinnamon-session
        * .config/gtk-2.0
        * .config/gtk-3.0
    * ```sudo apt-get purge cinnamon```
    * reboot
    * ```sudo apt install gnome-tweaks```
        * Tweaks -> Keyboard & Mouse -> Additional Layout Options -> Miscellaneous compatibility options -> Numlock on: Windows like
    * ```sudo apt install gnome-shell-extensions```
        * Reboot
        * Gnome Tweaks > Extensions > Enable User Themes
            * This will fix: ```shell user theme extension not enabled```
        *  Gnome Tweaks > Appearance > Shell > Yaru-dark
    * Check your gnome shell version: gnome-shell --version
    * Install arc menu for the correct version:
        * ```git clone --single-branch --branch gnome-3.36/3.38 https://gitlab.com/arcmenu/ArcMenu.git```
        * ```cd ArcMenu```
        * ```make install```
        * reboot
    * Install dash to panel for the correct version:
        * ```git clone -b gnome-3.38 --single-branch https://github.com/home-sweet-gnome/dash-to-panel.git```
        * switch to the correct version branch
        * ```make install```
        * reboot
    * Tweaks -> Appearance -> Shell -> Yaru-dark
    * ArcMenu Settings
        * General -> Modify Activities Hot Corner -> Settings -> Hot Corner Action -> Disabled
        * General -> Choose a Hotkey for ArchMenu -> Left Super Key
        * Menu Layout -> Modern Menu Layouts -> Windows
        * Menu Layout -> Windows -> Disable Frequent Apps
        * Customize Menu -> Menu Settings -> Menu Hight -> Max
        * Customize Menu -> Menu Settings -> Left-Panel Width-> Min
        * Customize Menu -> Menu Settings -> Right-Panel Width-> Max
    * Dash to Panel Settings:
        * Position -> Panel screen position -> Right
        * Position -> Activities button -> visible + down
        * Position -> Show Applications button -> Visible off
        * Behavior -> Isolate Workspace -> ON
        * Fine-Tune -> Status Icon Padding -> 5px

    * **Remove Mint packages**
        * ```sudo apt purge mintupdate```
        * ```sudo apt purge mintreport```
        * ```sudo apt purge mintdrivers```
        * ```sudo apt purge lightdm```
        * ```sudo apt purge lightdm-settings```

* **Gnome Shortcuts**
    * Show all workspaces
        * Windows/super + D
            * Distro???
        * Windows/super + S
            * Ubuntu 20.04 LTS

* Settings -> Mouse & Touchpad -> Touchpad -> Tap to Click -> ON

* Nemo -> Edit -> Preferences -> View New folder using -> List View -> Inherit from parent

* **Increase Battery Life**
    * POTENTIAL SYSTEM INSTABILITY
    * https://github.com/AdnanHodzic/auto-cpufreq
        * ```git clone https://github.com/AdnanHodzic/auto-cpufreq.git```
        * ```cd auto-cpufreq && sudo ./auto-cpufreq-installer```
        * ```sudo auto-cpufreq --install```
        * ```auto-cpufreq --stats```

* **Second Drive Auto Mount**
    * Open Disks app
    * Select Drive
    * Select Partition
    * More actions (cogs icon) -> Edit Mount Options -> auto mount

* **Rhythmbox add folders as playlists**
    * Don't use Rhytmbox. It lacks customizations like song repeate etc.
        * New automatic playlist -> Path + Contains + my_folder -> Add if any criteria are matched

* **Music Player**
    * Exaile
        * Cover art is too small.
            * There is an extension support but I haven't checked it for a big cover support.
    * Rhytmbox
        * Lacks customizations like song repeate etc.
        * Hard to add local folders
    * Quod Libet
        * Unintuitive GUI and small cover art.
        * Hard to add local folders
    * QMMP
        * Couldn't find a folder add button.
    * Sayonara Player
        * Perfect.
            * Disable notifications from gnome settings:
                * Settings > Notifications > Applications > Sayanora Player > Off
            * Disable notifications from the app:
                * Preferences > Notifications > Not Active

* **windirstat alternative (storage/statistics/diagram/free/space)**
    * k4dirstat

* **System wide equalizer (Sound/Music)**
    * POSSIBLE CONFLICT WITH THE SYSTEM DEFAULT AUDIO MANAGERS
    * ```sudo apt install pulseeffects```
    * ```sudo apt install lsp-plugins```
    * Log out or reboot

* **RTX Voice Alternative: NoiseTorch (Noise/cancel/audio)**
    * Download and install the app
    * Select input and output from system options
        * Gnome Settings -> Sound -> Output Device -> LDSPA Plugin NoiseTorch rnnoise

* **Microsoft Paint Alternative (Draw/Crop/Image)**
    * kolourpaint4

* **Ubuntu 18.04 Gnome Dark Theme**
    * ```gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'```

* **QT Creator dependencies**
    * One of the possible errors: "qt.qpa.plugin: Could not load the Qt platform plugin "xcb" in "" even though it was found."
    * [HERE QT WIKI](https://wiki.qt.io/Building_Qt_5_from_Git)

* **Install ARM compiler**
    * ```sudo apt-get install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf```

* **Modelsim text editor font is too small can't see**
    * Use Ctrl + (Numlock+) to zoom in

* **How to create a bootable USB (Rufus/iso/image/)**
    * WoeUSB-ng
        * ```sudo apt install git p7zip-full python3-pip python3-wxgtk4.0 grub2-common grub-pc-bin```
        * ```sudo pip3 install WoeUSB-ng```
        * Search for woeusb among all applications.
    * UNetbootin
        * Not tested
    * Balena Etcher
        * Works only for Linux isos.
        * Windows ISO doesn't boot.
    * Ventoy
        * May not work
    * MultiWriter
        * May not work
    * Use dd command
        * May not work
        * ```sudo dd if=/to/iso_file of=/to/usb_drive bs=1M status=progress```

* **Cinnamon Shortcuts**
    * Show all workspaces
        * Ctrl + Alt + Up
    * Switch workspaces
        * Ctrl + Alt + Left/Right

* **Cinnamon Customizations**
    * Window Tiling -> Tiling and snapping -> Maximize instead of tile when window gragged to the top edge
    * Fix unreadable black text on Mint-Y Dark theme.
        * Open /usr/share/themes/Mint-Y-Dark/gtk-3.0/gtk.css
        * Change color to white:
        ```calendar-view event.color-light label {  color: white; }```
    * Hot Corners -> Enable right-down corner -> show desktop
    * Right click show desktop applet -> remove
    * Right click panel -> move -> right
    * Settings -> Keyboard -> Layouts -> Options -> Miscellaneous Compatibility Options -> Shift with Numeric Keypads works as in MS Windows
    * Sound -> sounds -> Changing the sound volume -> logout.ogg
    * Sound -> sounds -> Starting Cinnamon -> off
    * Applets -> expo view -> enable
    * Applets -> Seperator -> add after expo view
    * Applets -> Spacer -> add after expo view
    <!---
    * Applets -> Workscape switcher -> enable
        * Config -> Basic visual representation -> disable
    * Applets -> Seperator -> add after workspace switcher
    * Applets -> Spacer -> add after workspace switcher
    -->
    * Applets -> Install -> Cinnamenu
        * Config -> Search:
            * Emoji search -> off
            * Search home folder -> off
            * Search -> Web search option -> none
        * Config -> Behaviour:
            * Enable Auto Scrolling -> off
            * Activate categories on click -> on
            * Open menu on category -> Last used category
        * Config -> Layout and content:
            * Content -> disable all
            * Content -> Open the menu editor:
                * New Menu -> "My"
                * My:
                    * Add existing app:
                        * App -> Right click -> cut
                        * My -> Right click -> Paste
                    * Add new items:
                        * New Item -> fill name icon command
        * Config -> Appearance:
            * Menu -> Category icon size -> 14
            * Menu -> Applications list icon size -> 14
            * Menu -> Applications grid icon size -> 40
            * Menu -> Sidebar icon size -> 14

* **Limit download and upload speeds for a network interface**
    * ```sudo apt install wondershaper```
    * Limit download to 8000kbps upload to 9999kbps for wlp7s0 interface
        * ```sudo wondershaper wlp7s0 8000 9999```
    * Remove limiter for an interface
        * ```sudo wondershaper clear wlp7s0```

* **Produce high CPU load on a Linux (benchmark)**
    * ```openssl speed -multi $(grep -ci processor /proc/cpuinfo)```

* **Monitor CPU/GPU temperatures in game like MSIAfterburner**
    * Don't forget to enable it from Lutris:
        * Settings > Global Settings > ManghoHUD FPS Counter > Enable
    * Direct install but this may not work:
        * ```sudo add-apt-repository ppa:flexiondotorg/mangohud```
        * ```sudo apt update```
        * ```sudo apt install mangohud```
    * Build yourself:
        * ```git clone --recurse-submodules https://github.com/flightlessmango/MangoHud.git```
        * ```cd MangoHud```
        * ```./build.sh build```
        * ```./build.sh package```
        * ```./build.sh install```

* **How to tweak MangoHUD via GUI**
    * GOverlay

* **How to find a directory**
    * ```find . -type d | grep DIRNAME```

* **PopOS customizations**
    * Settings -> Mouse and Touchpad -> Touchpad -> Natural Scrolling -> Enable
    * The rest is the same as previous gnome instructions

* **Install Archmenu and Dash to panel via command line interface**
    * These may not work or require a restart:
        * ```sudo apt-get install -y gnome-shell-extension-arc-menu```
        * ```sudo apt-get install -y gnome-shell-extension-dash-to-panel```

* **Matlab install can't start with sudo (superuser permissions)**
    * ```xhost +SI:localuser:root```

* **Kolourpaint missing icons**
    * Install breeze icon theme
        * ```sudo apt install breeze```

* **Internal Display Overclocking with xrandr (Hz/monitor)**
    * DOES NOT WORK ON A LAPTOP
    * Find the port the monitor is connected to:
        * ```xrandr | grep -Pio '.*?\sconnected'```
    * Install cvt12 for reduced timing calculation. [Ignore, if you have your timings]
        * ```cd ~/ && wget https://raw.githubusercontent.com/kevinlekiller/cvt_modeline_calculator_12/master/cvt12.c && gcc cvt12.c -O2 -o cvt12 -lm -Wall```
        * ```cd ~/ && ./cvt12 1920 1080 109 -b```
    * Create a new xrandr mode with the timings:
        * ```xrandr --newmode "1920x1080_72.00_rb" 167.28 1920 1968 2000 2080 1080 1103 1108 1117 +hsync -vsync```
    * Add the mode to your monitor port
        * ``` xrandr --addmode HDMI1 1920x1080_72.00_rb```
    * Activate the mode
        * ``` xrandr --output HDMI1 --mode 1920x1080_72.00_rb```

* **Internal Display Overclocking with EDID (Hz/monitor)**
    * DOES NOT WORK ON A LAPTOP
    * Find your GPU
        * ```lspci | grep -Pi 'intel.*graphics'```
    * Find the port the monitor is connected to:
        * ```xrandr | grep -Pio '.*?\sconnected'```
    * Find the edid file using the above information:
        * ```sudo find /sys/devices/ -name edid```
    * Copy the edid to your home folder:
        * ```sudo cp /sys/devices/pci0000:00/0000:00:02.0/drm/card0/card0-HDMI-A-1/edid ~/edid.bin```
    * Install GHex
        * ```sudo apt install ghex```
    * Open the edid file in AW Edid Editor (use wine if you need to)
        * Head to the "Detailed Data" tab.
        * Edit block 1 accordingly
        * Save edid and exit
    * Use grub to write it
        * https://unix.stackexchange.com/questions/680356/i915-driver-stuck-at-40hz-on-165hz-screen

* **Internal Display Overclocking for a laptop with EDID (Hz/monitor)**
    * [SOURCE](https://unix.stackexchange.com/questions/680356/i915-driver-stuck-at-40hz-on-165hz-screen)
    * Get EDID binary of your monitor: `cp /sys/devices/pci0000\:00/0000\:00\:02.0/drm/card0/card0-eDP-1/edid ~/edid.bin` (eDP-1 is screen, 0000:00:02.0 is Intel driver's PCIe Bus ID. You can use lspci ve xrandr to get them.)
    * Open the edid.bin file with Windows or Wine with this program: https://www.analogway.com/americas/products/software-tools/aw-edid-editor/
    * From "Detailed Data" tab, use "CVT 1.2 Wizard" and write something like 144hz refresh rate. (Because of 165hz's pixel rate is above 655Mhz, it is not accepting 165hz. So you should enter something smaller.)
    * Copy the edited `edid.bin` file to `/lib/firmware/edid/edid.bin`
    * On file `/etc/default/grub`, change `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"` like this: `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash drm.edid_firmware=eDP-1:edid/edid.bin"`
    * Save this script to `/etc/initramfs-tools/hooks/edid` and run `sudo chmod +x /etc/initramfs-tools/hooks/edid` to make it executable:
    ```bash
        #!/bin/sh
        PREREQ=""
        prereqs()
        {
            echo "$PREREQ"
        }

        case $1 in
        prereqs)
            prereqs
            exit 0
            ;;
        esac

        . /usr/share/initramfs-tools/hook-functions
        # Begin real processing below this line
        mkdir -p "${DESTDIR}/lib/firmware/edid"
        cp -a /lib/firmware/edid/edid.bin "${DESTDIR}/lib/firmware/edid/edid.bin"
        exit 0
    ```
    * Run `sudo update-initramfs -u` and `sudo update-grub`
    * Reboot

* **Sticky Notes**
    * Linux Mint Cinnamon:
        * There were dependency problems on the latest gnome version.
        * ```sudo apt install sticky```
    * XFCE-Notes:
        * Darkmode fonts are broken. Colors can't be changed.
        * ```sudo apt-get install -y xfce4-notes```
    * Xpad
        * Broken in PopOs-21.10.
        * ```sudo apt-get install -y xpad```
    * Knotes
        * Bazillion dependencies in gnome.
        * ```sudo apt install knotes```
    * Indicator-Stickynotes
        * <s>No color customization.</s> There are colors:
            * Settings > New Category > Background Color
        * No direct local file sync support.
        * ```sudo apt install indicator-stickynotes```
    * Tomboy-ng
        * Not a sticky note app. Useless for me.

* **Installed pip module not found (pip/python/path)**
    * Add `~/.local/bin` to your $PATH:
        * Paste this line to `.bashrc`
            * `export PATH="$HOME/.local/bin:$PATH"`
    * Or install it with sudo privilages.
        * ```sudo pip install sync-dl```

* **How to install different proton versions easily**
    * Use ProtonUP-QT to install all versions of proton.
    * Use Lutris to install the slightly old version of proton.

* **How to run android apps on Linux**
    * Waydroid
        * But, its complicated to setup. You will waste hours. You need a kernel with enabled bindings. Please use Windows. Don't waste your time.

* **Archive Manager can't open password protected zip file**
    * ```sudo apt-get install p7zip```
    * ```sudo apt-get install p7zip-full```
    * ```sudo apt-get install p7zip-rar```

* **Archive Manager can't extract rar file**
    * ```sudo apt install unrar```

* **No suitable Java Virtual Machine could be found on your system**
    * ```sudo apt install default-jre```

* **How to download Youtube Playlist**
    * Jdownloader2

* **How to install logisim**
    * Flatpak
    * Snapstore
    * Deb
        * ```sudo apt install logisim```

* **VSCode LaTeX Workshop is not working**
    * Be sure to intsall a LaTeX compiler:
        * ```sudo apt-get install -y texlive-full ```

* **Jdownloader2 Dark Mode**
    * Settings > Advanced Settings:
        * On the search bar type "theme" (without the " "s), and change the value from DEFAULT to BLACK_EYE.
        * JD will prompt you to download and install the theme package, click Ok, and install.
        * Close and reopen JDownloader
        * In the Advanced Settings search bar, type "color back".
        * Change all the whites and light blues to dark grey or black.
        * On Advanced Settings, search "color fore", and change all the blacks and whites to white.
        * Finally search "color text", and change all the colors to white. Only the "Config Label Disabled Text Color" goes grey.
        * Restart JDownloader and your dark theme should be all set up.
        * Every time JD updates, the color settings will be back to default, and it will look messed up, simply close and reopen JD again, and the colors should be back to normal.

* **How to replace snaps with flatpak(fucking snaps)**
    * Before unsnapping, test video acceleration on firefox, videos, vlc etc.
    * https://github.com/popey/unsnap
        * After it is done. You can replace flatpak's with apt.
            * `flatpak list`
            * `flatpak remove <app_name>`
        * Firefox from ppa
            * ```sudo add-apt-repository ppa:mozillateam/ppa```
            ```
                echo '
                Package: *
                Pin: release o=LP-PPA-mozillateam
                Pin-Priority: 1001
                ' | sudo tee /etc/apt/preferences.d/mozilla-firefox
            ```
            * ```echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox```
            * ```sudo apt install firefox```

* **Replace Nautilus with Nemo on Ubuntu**
    * ```sudo apt update```
    * ```sudo apt install nemo```
    * ```xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search```
    * ```gsettings set org.gnome.desktop.background show-desktop-icons false```
    * ```gsettings set org.nemo.desktop show-desktop-icons true```

* **How to update python version Ubuntu LTS**
    * WARNING! THIS WILL PROBABLY BREAK YOUR SYSTEM. DONT UNLESS YOU KNOW WHAT YOU ARE DOING.
    * ```sudo add-apt-repository ppa:deadsnakes/ppa```
    * ```sudo apt-get update```
    * ```apt list | grep python3.10```
    * ```sudo apt-get install python3.10```
    * ```sudo apt-get install python3.10-distutils```
    * ```sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1```
    * ```sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2```
    * WARNING! THIS WILL PROBABLY BREAK YOUR SYSTEM. DONT UNLESS YOU KNOW WHAT YOU ARE DOING.
        * Change python version system wide:
            * ```sudo update-alternatives --config python3```
            * Select the version you want.
            * ```python3 -V```
    * Call newly installed version to test:
        * ```python3.10 -V```
    * Install a package with pip:
        * ```python3.10 -m pip install my_package_name```
            * Possible error:
                * ```ImportError: cannot import name 'html5lib' from 'pip._vendor' (/usr/lib/python3/dist-packages/pip/_vendor/__init__.py) [duplicate]```
                * Solution([source](https://stackoverflow.com/questions/70431655/importerror-cannot-import-name-html5lib-from-pip-vendor-usr-lib-python3)): `curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10`
1
l
* **Enter Shell on Login Screen**
    * CTRL+ALT+F3

* **Install Xilinx Tools(Vivado/Vitis)**
    * Install Required extra libs(Ubuntu LTS 20.04.03):
        ```console
        sudo apt update
        sudo apt upgrade
        sudo apt install libncurses5
        sudo apt install libtinfo5
        sudo apt install libtinfo-dev
        sudo apt install libncurses5-dev libncursesw5-dev
        sudo apt install ncurses-compat-libs
        sudo apt-get install libstdc++6:i386
        sudo apt-get install libgtk2.0-0:i386
        sudo apt install net-tools
        sudo apt install libc6-dev-i386
        sudo apt-get install build-essential
        ```
        * Reboot

* **Install Video Codecs on Ubuntu**
    * ```sudo apt-get install ubuntu-restricted-extras```

* **Disable Ubuntu tracker_miner_fs indexing**
    * ```gsettings set org.freedesktop.Tracker.Miner.Files crawling-interval -2```
    * ```gsettings set org.freedesktop.Tracker.Miner.Files enable-monitors false```

* **How to get full path of original file of a soft symbolic link?**
    * ```ls -l```

* **List all serial devices (UART/RS232)**
    * ```cat /sys/class/tty```

* **Serial Terminal Application**
    * Always use sudo
        * Hterm like: Cutecom
        * Putty like: Putty

* **Ubuntu sudo update too slow**
    * Change default PPA server:
        * Open Software & Update
        * Download from: -> Other -> Select Best Server -> Choose Server

* **Quartus Required Libraries**
    ```bash
        sudo add-apt-repository ppa:linuxuprising/libpng12
        sudo apt update
        sudo apt install libpng12-0
    ```

* **Nios II Eclipse IDE Erros**
    * ```(Eclipse:158225): Gtk-WARNING **: 18:33:11.016: Negative content width -1 (allocation 1, extents 1x1) while allocating gadget (node trough, owner GtkProgressBar)```
        * ```export SWT_GTK3=0```
        * ```export SWT_WEBKIT2=1```
        * Launch Eclipse:
            * ```./eclipse-nios2```
    * ```free(): invalid pointer```
        * Download java 8
            * ```sudo apt install openjdk-8-jre-headless```
        * Find its location
            * ```update-alternatives --list java```
        * Go to quartus folder
            * ```cd <install_path>/quartus/linux64```
        * Rename old jre
            * ```mv jre64 jre64_old```
        * Link new jre: (the location you found previously)
            * ```ln -s /usr/lib/jvm/java-8-openjdk-amd64/jre jre64```
        *  ```sudo nano /etc/java-8-openjdk/accessibility.properties```
           *  Comment the following line
                * ```#assistive_technologies=org.GNOME.Accessibility.AtkWrapper```
    * ```Failed to load module "canberra-gtk-module"```
        * ```sudo apt install libcanberra-gtk-module libcanberra-gtk3-module```
    * ```Failed to execute: ./create-this-bsp --cpu-name nios2_gen2_0 --no-make```
        * There could be a lot of reasons.
        * First find the file: `./create-this-bsp`
            * It is probably inside the `<project>/software` folder.
            * Run it in terminal and find the source of the error.
            * Eclipse internal terminal also shows errors.
    * ```Assistive Technology not found: org.GNOME.Accessibility.AtkWrapper```
        *  ```sudo nano /etc/java-8-openjdk/accessibility.properties```
           *  Comment the following line
                * ```#assistive_technologies=org.GNOME.Accessibility.AtkWrapper```
    * ```SEVERE: .entry section mapping not created because reset memory region not located at base address: 0xffffffffffffffff```
        * in QSYS->System Contents , right click your Nios cpu -> Edit...
        * in the tab "Core NiosII", check if "reset vector memory" points to a memory module and not e.g. jtag etc.
        * same with "exception vector memory"
        * after correction : QSYS->Generation->Generate
    * ``` error while loading shared libraries: libfl.so.2: cannot open shared object file: No such file or directory```
        * ```sudo apt-get -y install libfl-dev```
        * ```sudo apt-get -y install libncursesw5```

* **Quartus USB Blaster II not visible**
    * Add the USB device via udev
        * ```sudo nano /etc/udev/rules.d/51-usbblaster.rules```
        * Write these 3 lines:
            * ```# USB-Blaster II```
            * ```SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666", GROUP="plugdev"```
            * ```SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666", GROUP="plugdev"```
        * Restart udev
            * ```sudo service udev restart```
    * If the upper one didn't work:
    ```bash
        # USB-Blaster
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="0666", SYMLINK+="usbblaster/%k"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", MODE="0666", SYMLINK+="usbblaster/%k"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", MODE="0666", SYMLINK+="usbblaster/%k"

        # USB-Blaster II
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", MODE="0666", SYMLINK+="usbblaster2/%k"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", MODE="0666", SYMLINK+="usbblaster2/%k"

        SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", GROUP="plugdev", MODE="0666", SYMLINK+="usbblaster"



        # USB Blaster
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666", NAME="bus/usb/$env{BUSNUM}/$env{DEVNUM}", RUN+="/bin/chmod 0666 %c"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666", NAME="bus/usb/$env{BUSNUM}/$env{DEVNUM}", RUN+="/bin/chmod 0666 %c"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666", NAME="bus/usb/$env{BUSNUM}/$env{DEVNUM}", RUN+="/bin/chmod 0666 %c"

        # USB Blaster II
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666", NAME="bus/usb/$env{BUSNUM}/$env{DEVNUM}", RUN+="/bin/chmod 0666 %c"
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666", NAME="bus/usb/$env{BUSNUM}/$env{DEVNUM}", RUN+="/bin/chmod 0666 %c"
    ```

* **Quartus can't find libpng12-0.so**
    * Paste this to the `.bashrc`
        * `export QUARTUS_64BIT=1`
    * Run quartus via command line
    * Or pass `--64bit` flag.

* **Run an application in another gnome-terminal, detach and show no outputs**
    * ```nohup gnome-terminal --  bash -c "nohup /mnt/second/applications/launch_scripts/quartus >/dev/null 2>&1;  bash" >/dev/null 2>&1```

* **Add apps to application menu or Create desktop entries**
    * `sudo apt install alacarte`

* **How to run quartus in 64 bit mode**
    * Pass `--64bit` flag.
        * `quartus --64bit`

* **How to stop Ubuntu 20.04 from auto-adding network printers**
    * `systemctl stop cups-browsed`
    * `systemctl disable cups-browsed`

* **How to download a page as a single html document**
    * SingleFile Browser extension.

* **How to download an entire website for offline view**
    * Use wget:
        * ```wget -r https://zipcpu.com/```
    * Open them:
        * ```python3 -m http.server -d path/to/my/files```

* **Real time read write speed**
    * `sudo apt install iotop`

* **Turbo boost not working Ubuntu 20.04**
    * To view available speed governors use this command:
        ```cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors```
    * If you do have more than one governor you can check what is currently in use with this command:
        ```cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor```
    * To change your processor to performance mode use:
        ```echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor```

* **Monitor CPU Frequency**
    * ```watch -n1 "cat /proc/cpuinfo | grep "MHz""```

* **How to block domains**
    * Add the domain to `etc/hosts`
        * ```0.0.0.0 reddit.com```
    * If it doesn't work on Firefox:
        * Set `network.dns.offline-localhost` to false in about:config
    * If it still doesn't work:
        * Disable DNS over HTTPS

* **How to change wallpaper from command line GNOME**
    * ```gsettings set org.gnome.desktop.background picture-uri file:///mnt/second/images/art/0005.png```

* **Run bash script at startup**
    * Crontab method (Didn't work on Ubuntu 20.04)
        * Create your script and make it executable
            * ```chmod +x /home/user/startup.sh```
        * Set a crontab for it
            * ```crontab -e```
            * ```@reboot  /home/user/startup.sh```
    * /etc/rc.local method (gnome commands didn't work)
        * Add a command to launch your script
            * ```/PATH/TO/MY_APP &```
        * Or paste all commadns there
    * Use Ubuntu Startup Application GUI App(Works)
        * Search it.
        * Add the script or command
        * Reboot and observe

* **Run bash script at startup with sudo**
    * Create a file: ```/etc/rc.local```
    * Fill it with your bash code
    * ```sudo chmod +x /etc/rc.local```

* **Single wifi card hotspot Ubuntu**
    * Install:
    ```bash
        sudo add-apt-repository ppa:lakinduakash/lwh
        sudo apt install linux-wifi-hotspot
    ```

* **Ubuntu 20.04 LTS Ethernet is dropping after a minute(wired,network)**
    * Install old drivers:
    ``` sudo apt install r8168-dkms```

* **PDF Editor**
    * Okular

* **Okular Dark Mode Ubuntu 20**
    * ```sudo apt-get install qt5-style-plugins```
    * Test if the theme is to your liking:
        * ```QT_QPA_PLATFORMTHEME=gtk2 okular```
    * If yes add this to `/etc/enviroment` as a newline.
        * ```QT_QPA_PLATFORMTHEME=gtk2```

* **Okular invert pdf colors**
    * Settings -> Accesibility -> Colors -> Invert

* **SQL Client/Viewer**
    * sqlectron

* **Create a password protected zip file without compression**
    * ```7z a -mx=0 -mem=AES256 -p"my_password" "output.zip" directory_name```

* **How to edit pdf files, How to add image to pdf**
    * ```sudo apt-get install xournal```

* **Offline/Online Microsoft ToDo Client**
    * Kuro (github)

* **Wine Apps Dark Theme**
    * The files are in the `./scripts` folder.
    * Install
        * ```wine regedit wine-breeze-dark.reg```
    * Uninstall (Reset Wine color scheme)
        * ```wine regedit wine-reset-theme.reg```

* **Apply dos2unix recursively (line endings/\r\n)**
    * ```find /path -type f -print0 | xargs -0 dos2unix --```

* **Backup system**
    * Timeshift

* **Install Docker**
    * Source: `https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04`
    * ```sudo apt install apt-transport-https ca-certificates curl software-properties-common```
    * ```curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -```
    * ```sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"```
    * ```apt-cache policy docker-ce```
    * ```sudo apt install docker-ce```
    * ```sudo systemctl status docker```
    * ```sudo usermod -aG docker ${USER}```
    * ```su - ${USER}```
    * ```docker run hello-world```
    * ```exit```
    * ```exit```
    * If permission error:
        * ```sudo chmod 666 /var/run/docker.sock```

* **Convert TXT to PDF**
    * ```libreoffice --convert-to "pdf" input.txt```

* **Crystal DiskMark Equivalent**
    * KDiskmark
        * `sudo add-apt-repository ppa:jonmagon/kdiskmark`
        * `sudo apt install kdiskmark`

* **Install QEMU/KVM Virtual Machine**
    * Run the command and be sure it is not zero.
        * `egrep -c '(vmx|svm)' /proc/cpuinfo`
    * Install cpu checker.
        * `sudo apt install cpu-checker`
    * Check if KVM ready
        * `sudo kvm-ok`
    * Install dependencies.
        * `sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils`
    * Add user to groups.
        * `sudo adduser emre libvirt`
        * `sudo adduser emre kvm`
    * Check if virtualization is running.
        * `sudo systemctl status libvirtd`
        * If not run this to run it.
            * `sudo systemctl enable --now libvirtd`
    * Install virt-manager
        * `sudo apt-get install virt-manager`
    * Run virt-manager as sudo
        * `sudo virt-manager`
    * You can use the VM as it is now. But, follow along if you want more performance.
    * Download virtio drivers stable iso.
        * [link](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)
    * Create a new virtual machine.
    * Select windows 10 iso.
    * Select/Create a virtual harddisk.
    * Select customize before install
    * CPUs -> Current Allocation -> 8
    * CPUs -> Topology -> Manually set -> 1 socket, 4 core, 8 threads
    * Add hardware -> Storage -> New CDROM : Bus type -> Sata
    * Select CDROM -> Source -> Virtio driver iso
    * IDE/SATA Disk 1 -> Advanced -> Disk Bus -> VirtIO
    * NIC:XX:xx:xx -> Device Model -> VirtIO
    * Video QXL -> Model -> Virtio : 3D enable
    * Begin Installation
    * It will not find the storage automatically.
        * Install drivers from virtIO iso.
        * If they don't pop automatically look into amd64 folder.
    * After the install open Device Manager.
        * Select Windows Basic Display Adapter
        * Search for drivers.
            * Point to the iso
        * Do the same for the ethernet driver

* **How to share folder KVM/QEMU Virt-Manager**
    * Virtiofs (Not supported in Ubuntu 20.04)[source](https://askubuntu.com/questions/1401151/unable-to-add-virtiofs-filesystem-to-qemu-vm-in-ubuntu-server-20-04-due-to-incom)
    * You have to build QEMU and KVM yourself.

* **Windows VM suddenly run very slow in KVM/QEMU**
    * [SOURCE](https://serverfault.com/questions/1092404/windows-vm-suddenly-run-very-slow-in-kvm-qemu)
        * On windows:
            * ```reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f```

* **Tile Manager**
    * ```sudo apt-get install -y tilix```
    * TILIX_SHORTCUTS
        * CTRL_SHIFT_B: open bookmarks

* **Change default editor**
    * ```sudo update-alternatives --config editor```

* **Terminal file manager**
    * ```sudo apt install ranger```

    * Change rifle.conf file to change default editor.
    * Use ranger after app launch
        * ```ext png, flag f = viewnior "$@"```

* **Save Gnome Terminal profile**
    * How to save it.
        * ```dconf dump /org/gnome/terminal/legacy/profiles:/ > gnome-terminal-profiles.dconf```
    * How to restore it.
        * ```dconf load /org/gnome/terminal/legacy/profiles:/ < gnome-terminal-profiles.dconf```

* **Bash Terminal Theme (zsh/startship)**
    * Install starship
        * https://starship.rs/
    * Add your config file (in ./scripts folder named starship.toml) to ~/.config/here

* **Don't install yosys from apt/aptitude**
    * It is an old version
    * Instead install OpenOCD suite

* **Don't enable linting in TerosHDL**
    * It can not find other files.
    * Use the famous verilog extension and activate linting.
        * Pass directories to iverilog and add include directories.
            * ```-y ./, -y ./rtl, -I ./ , -I ./rtl/```

* **Add custom context item to nemo**
    * Go to ```~/.local/share/nemo/actions```
    * Create a file named ```code.nemo_action```
    * Paste the following code
    ```
    [Nemo Action]

    Name=Open in Code
    Comment=Open the 'code' editor in the selected folder
    Exec=code %F
    Icon-Name=VSCode
    Selection=any
    Extensions=dir;
    ```

* **Simple screen recorder**
    * ```sudo apt-get install simplescreenrecorder```

* **Wine game mods are not detected/visible**
    * Override `winhttp`

* **Wine text are not visible**
    * Install fonts
        * Winetricks -> install a font -> allfonts

* **apt autoremove**
    * Never do that.
        * APT only knows about dependencies of the apps installed via apt.
        * All the portable apps will be crippled.

* **OPENRAM installation**
    * Be sure gitpreferences `autocrlf` is false.
    ```
    [core]
        autocrlf = false
        eol = lf
    ```
    * Download and install klayout
        * ```https://www.klayout.de/build.html```
    * ```sudo apt install magic```
    * ```sudo apt install netgen```
    * ```git clone https://github.com/VLSIDA/OpenRAM openram```
    * ```export OPENRAM_HOME="<install_path>/openram/compiler"```
    * ```export OPENRAM_TECH="<install_path>/openram/technology"```
    * ```export PYTHONPATH=$OPENRAM_HOME```
    * ```cd openram/docker```
    * ```make build```
    * ```cd openram```
    * ```make pdk```
    * ```make install``
    * if you encounter git pull problems
        * Either delete git pulls from make file
        * Or, git checkout master for openram and try again.

* **Sync folder with Google Drive**
    * ```sudo apt install rclone```
        * ```rclone config```
        * Follow the config

* **rclone sync folder with remote**
    * ```rclone sync -i SOURCE remote:DESTINATION```
        * Be careful. It will delete or create. No backup.
        * If the source is empty. Destination will also be empty.

* **Nemo File Manager open new instances as a new tab**
    * Edit each ```Exec=``` line in ```nemo.desktop``` to add the ```--existing-window``` flag.

* **Open new instances of terminal as a new tab**
    * Gnome terminal sucks. Use Tilix

* **How to set Tilix to nemo open terminal here option**
    * ```gsettings set org.cinnamon.desktop.default-applications.terminal exec tilix```

* **How to fill RAM**
    * ```echo {1..1000000000}```

* **How to enable zRAM**
    * Disable swap
        * ```sudo nano /etc/fstab```
        * Comment the line with swap
    * ```sudo swapoff /swapfile```
    * ```sudo apt install zram-config```
        * This will set half of the RAM az zRAM
    * Reboot
    * Change zRAM size
        * ```sudo nano /usr/bin/init-zram-swapping```
        * Change `/ 2`  accordingly
            * DO NOT set it higher than your system RAM.
            * The max you can do ise `/ 1`. Don't `*` it.
    * You can also change the algorithm.
        * ```cat /sys/block/zram0/comp_algorithm```
        * ```echo lz4 > /sys/block/zram0/comp_algorithm```

* **How to run apps without asking for a sudo password**
    * ```sudo visudo```
    * To the bottom:
        * ```username ALL=(ALL) NOPASSWD: /path/to/application```

* **How to install Consolas font**
```
wget -O /tmp/YaHei.Consolas.1.12.zip https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/uigroupcode/YaHei.Consolas.1.12.zip
unzip /tmp/YaHei.Consolas.1.12.zip
sudo mkdir -p /usr/share/fonts/consolas
sudo mv YaHei.Consolas.1.12.ttf /usr/share/fonts/consolas/
sudo chmod 644 /usr/share/fonts/consolas/YaHei.Consolas.1.12.ttf
cd /usr/share/fonts/consolas
sudo mkfontscale && sudo mkfontdir && sudo fc-cache -fv
```
* **How to install Cascadia Code**
    * Download the ttf files from github
    * Double click

* **How to create symlink for an app**
    * ```ln -s source_file symbolic_link```
    * ```ln -s /mnt/shared/applications/lin/vscode/code code```

* **Grub menu is not visible**
    * set GRUB_TIMEOUT_STYLE=menu and GRUB_TIMEOUT=10 in /etc/default/grub and updated the grub, try setting (uncommenting) GRUB_TERMINAL=console as well and re sudo update-grub .
    * sudo os-prober

* **Windows not visible on grub menu**
    * Use this:
        * ```
          sudo add-apt-repository ppa:yannubuntu/boot-repair
          sudo apt-get update
          sudo apt-get install -y boot-repair
          ```


* **Include file to bashrc if exists**
    * s
    ```
    # include .bashrc if it exists
    if [ -f /mnt/second/rep/personal_repo/code_snippets/my_bashrc ]; then
        . /mnt/second/rep/personal_repo/code_snippets/my_bashrc
    fi
    ```






















----------------------------------
## CUSTOMIZATIONS
* **Nice terminal app**
    * Install it
        * ```sudo apt install zsh```
    * Make your default shell
        * ```chsh -s $(which zsh)```


# Define the "editor" for text files as first action "gpedit" is selected
```
mime ^text,  label editor = gedit -- "$@"
mime ^text,  label pager  = $PAGER -- "$@"
!mime ^text, label editor, ext xml|json|csv|tex|py|pl|rb|rs|js|sh|php|dart, flag f = gedit -- "$@"
!mime ^text, label pager,  ext xml|json|csv|tex|py|pl|rb|rs|js|sh|php|dart = $PAGER -- "$@"
```
* IDK:
```
    Open the console with the content "shell %s", placing the cursor before the " %s" so you can quickly run commands with the current selection as the argument.
    So, highlight the files you want to work on with Space type @ to get to a command prompt which will be :shell  %s with the cursor positioned before %s

    type the name of your command and press Enter

    the command you specified will be executed with selected filenames as parameters
```
* Press 'y' to see the shortcuts
    * yd - copy directory name only
    * yn - copy file name only
    * yp - copy full path
    * zh - toggle hidden file visibility

* List app installation folder:
    * dpkg -L gedit // list installation folders

* https://github.com/trapd00r/LS_COLORS

