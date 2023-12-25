function i_qmk(){
    sudo pacman -S --noconfirm --needed qmk
}

function i_qemu() {
    # Install QEMU
    sudo pacman -S --noconfirm --needed qemu-emulators-full 
    # sudo pacman -S --noconfirm --needed qemu-desktop
    sudo pacman -S --noconfirm --needed dnsmasq
    sudo pacman -S --noconfirm --needed virt-manager
    sudo pacman -S --noconfirm --needed iptables-nft
    sudo pacman -S --noconfirm --needed libvirt

    sudo virsh net-start default
    sudo systemctl enable --now libvirtd
    sudo gpasswd -a $USER libvirt
    sudo gpasswd -a $USER kvm

    # You should reboot again after you open virt-manager first time
}

function i_vmware() {
    sudo pacman -S --noconfirm --needed fuse2
    sudo pacman -S --noconfirm --needed libcanberra
    sudo pacman -S --noconfirm --needed pcsclite
    sudo pacman -S --noconfirm --needed linux-headers
    sudo pacman -S --noconfirm --needed gtkmm
    yay -S --noconfirm --needed ncurses5-compat-libs
    yay -S --noconfirm --needed  vmware-workstation
    sudo systemctl enable vmware-networks.service  vmware-usbarbitrator.service vmware-hostd.service
    sudo systemctl start vmware-networks.service  vmware-usbarbitrator.service vmware-hostd.service
    sudo modprobe -a vmw_vmci vmmon
}

function i_wine_nvidia() {
    # Windows Emulation/Layer
    sudo sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf
    sudo pacman -Syu # must syu after multilib
    sudo pacman -S --noconfirm --needed wine
    sudo pacman -S --noconfirm --needed winetricks
    sudo pacman -S --noconfirm --needed zenity
    sudo pacman -S --noconfirm --needed lutris
    sudo pacman -S --noconfirm --needed lib32-nvidia-utils
    sudo pacman -S --noconfirm --needed xdg-desktop-portal-hyprland
    sudo pacman -S --noconfirm --needed xdg-desktop-portal-gtk
    sudo pacman -S --noconfirm --needed nvidia
    sudo pacman -S --noconfirm --needed nvidia-prime
}

function i_xremap() {
    yay -S --noconfirm --answerdiff=None --needed xremap-hypr-bin
    echo "uinput" | sudo tee -a /etc/modules-load.d/uinput.conf
    sudo gpasswd -a $USER input
    echo 'KERNEL=="uinput", GROUP="input", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-input.rules
}

function i_y_core() {
    yay -S --noconfirm --answerdiff=None --needed btop-gpu-git
    yay -S --noconfirm --answerdiff=None --needed k4dirstat
    yay -S --noconfirm --answerdiff=None --needed asusctl
    yay -S --noconfirm --answerdiff=None --needed rog-control-center
    yay -S --noconfirm --answerdiff=None --needed wlr-randr # Dep for nwg-displays
    yay -S --noconfirm --answerdiff=None --needed wlr-randr
}


function i_core() {
    sudo pacman -S --noconfirm --needed gnome-disk-utility
    # sudo pacman -S --noconfirm --needed gnome-system-monitor # -> btop
    sudo pacman -S --noconfirm --needed gnome-bluetooth-3.0
    sudo pacman -S --noconfirm --needed gnome-power-manager
    sudo pacman -S --noconfirm --needed upower
    sudo pacman -S --noconfirm --needed tk
    sudo pacman -S --noconfirm --needed gnome-themes-extra
    sudo pacman -S --noconfirm --needed adwaita-qt5
    sudo pacman -S --noconfirm --needed adwaita-qt6
    sudo pacman -S --noconfirm --needed swayidle
    sudo pacman -S --noconfirm --needed wireplumber
    sudo pacman -S --noconfirm --needed grim
    sudo pacman -S --noconfirm --needed slurp

    sudo pacman -S --noconfirm --needed blueman
    sudo pacman -S --noconfirm --needed bluez
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service
}

function i_vieb(){
    sudo pacman -S --noconfirm --needed vieb-bin
    # [ ] lf file picker
        # https://github.com/Jelmerro/Vieb/issues/339
}

function i_qb(){
    # https://github.com/qutebrowser/qutebrowser/blob/9f8e9d96c85c85a605e382f1510bd08563afc566/misc/userscripts/README.md
    sudo pacman -S --noconfirm --needed qutebrowser
    sudo pacman -S --noconfirm --needed python-adblock
    sudo pacman -S --noconfirm --needed python-tldextract
    sudo pacman -S --noconfirm --needed rofi # qute-pass dependency
    # Missing:
        # [ ] Vimium like hint accuracy
        # [ ] Usable pinned tabs/bookmarks
            # https://www.reddit.com/r/qutebrowser/comments/ixrvgb/struggling_alittle_with_learning_how_to_manage/
            # https://www.reddit.com/r/qutebrowser/comments/gcqwv2/how_do_you_guys_manage_your_bookmarksquickmarks/
        # [x] Cross Platform Password Auto Fill
            # https://github.com/unode/firefox_decrypt
            # https://github.com/qutebrowser/qutebrowser/blob/main/misc/userscripts/qute-pass
            # https://github.com/android-password-store/Android-Password-Store
        # [x] Dark mode
            # https://www.reddit.com/r/qutebrowser/comments/zmqey6/an_update_on_the_status_of_dark_mode/
            # https://www.reddit.com/r/qutebrowser/comments/cc5vov/dark_mode_in_qutebrowser
            # https://github.com/qutebrowser/qutebrowser/blob/main/doc/faq.asciidoc
        # [x] Video speed controls
            # https://www.reddit.com/r/qutebrowser/comments/os9hed/qutebrowser_video_speed_controller/
        # [x] Toggle video focus
            # https://github.com/qutebrowser/qutebrowser/issues/1354#issuecomment-1132289061
                # You can just scroll with jk
        # [x] lf file picker
            # https://github.com/gokcehan/lf/discussions/1080
            # https://www.youtube.com/watch?v=ce2NOmTBWfo
        # [x] ublock capabilities
            # [x] youtube adblock
                # Greasemonkey script
            # [x] cosmetic blockers
                # https://github.com/qutebrowser/qutebrowser/issues/6480#issuecomment-1820106001
}

function i_bunch() {
    # sudo pacman -S --noconfirm --needed direnv # out of date
    sudo pacman -S --noconfirm --needed unrar
    sudo pacman -S --noconfirm --needed p7zip
    sudo pacman -S --noconfirm --needed zip
    sudo pacman -S --noconfirm --needed unarchiver
    sudo pacman -S --noconfirm --needed udiskie

    # Check /run/user/1000/gvfs directory for mtp devices mounted by nemo
    # Check /tmp/mtp directory for mtp devices mounted by lf
    # sudo pacman -S --noconfirm --needed nemo # -> lf
    # sudo pacman -S --noconfirm --needed nemo-fileroller
    sudo pacman -S --noconfirm --needed wget
    sudo pacman -S --noconfirm --needed mpv
    sudo pacman -S --noconfirm --needed cronie
}

function i_helix() {
    sudo pacman -S --noconfirm --needed prettier     # markdown etc.
    sudo pacman -S --noconfirm --needed python-ruff  # python
    sudo pacman -S --noconfirm --needed rust-analyzer # rust
    sudo pacman -S --noconfirm --needed lldb
    sudo pacman -S --noconfirm --needed bash-language-server
    # yay -S --noconfirm --answerdiff=None --needed verible-git # verilog
}
