#!/usr/bin/env bash

# Update and upgrade packages
sudo pacman -Syu
# Download in parallel
sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
# Change the MAKEFLAGS value to use all available cores
sudo sed -i '/^#MAKEFLAGS=/s/^#//' /etc/makepkg.conf
sudo sed -i 's/^MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf


function i_yay() {
    # Install yay
    sudo pacman -S --noconfirm --needed git
    sudo pacman -S --noconfirm --needed base-devel
    git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si
}

function i_qemu() {
    # Install QEMU
    sudo pacman -S --noconfirm --needed qemu-desktop
    sudo pacman -S --noconfirm --needed dnsmasq
    sudo pacman -S --noconfirm --needed virt-manager
    sudo pacman -S --noconfirm --needed iptables-nft
    sudo systemctl enable --now libvirtd
    sudo gpasswd -a $USER libvirt
    sudo gpasswd -a $USER kvm
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

function i_nf() {
    # Install a Nerd Font
    wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
    mkdir -p ~/.fonts
    unzip JetBrainsMono.zip -d ~/.fonts
    fc-cache -fv
    rm JetBrainsMono.zip
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
    yay -S --noconfirm --answerdiff=None --needed k4dirstat
    yay -S --noconfirm --answerdiff=None --needed swww
    yay -S --noconfirm --answerdiff=None --needed asusctl
    yay -S --noconfirm --answerdiff=None --needed rog-control-center
    yay -S --noconfirm --answerdiff=None --needed hyprshot
    yay -S --noconfirm --answerdiff=None --needed nwg-displays
    yay -S --noconfirm --answerdiff=None --needed wlr-randr
    yay -S --noconfirm --answerdiff=None --needed swaync
    yay -S --noconfirm --answerdiff=None --needed gtklock
    yay -S --noconfirm --answerdiff=None --needed etcher-bin
}

function i_network() {
    sudo pacman -S --noconfirm --needed waybar
    sudo pacman -S --noconfirm --needed networkmanager
    sudo pacman -S --noconfirm --needed network-manager-applet
    sudo pacman -S --noconfirm --needed gtk3
    sudo pacman -S --noconfirm --needed gtk-layer-shell
    sudo pacman -S --noconfirm --needed socat
    sudo pacman -S --noconfirm --needed polkit-gnome
    sudo pacman -S --noconfirm --needed libsecret
    sudo pacman -S --noconfirm --needed gnome-keyring
}

function i_core() {
    sudo pacman -S --noconfirm --needed ntfs-3g
    sudo pacman -S --noconfirm --needed less
    sudo pacman -S --noconfirm --needed gnome-disk-utility
    sudo pacman -S --noconfirm --needed gnome-system-monitor
    sudo pacman -S --noconfirm --needed gnome-bluetooth-3.0
    sudo pacman -S --noconfirm --needed gnome-power-manager
    sudo pacman -S --noconfirm --needed upower
    sudo pacman -S --noconfirm --needed brightnessctl
    sudo pacman -S --noconfirm --needed pavucontrol
    sudo pacman -S --noconfirm --needed ffmpeg
    sudo pacman -S --noconfirm --needed tk
    sudo pacman -S --noconfirm --needed gnome-themes-extra
    sudo pacman -S --noconfirm --needed adwaita-qt5
    sudo pacman -S --noconfirm --needed adwaita-qt6
    sudo pacman -S --noconfirm --needed swayidle
    sudo pacman -S --noconfirm --needed usbutils
    sudo pacman -S --noconfirm --needed wireplumber
    sudo pacman -S --noconfirm --needed grim
    sudo pacman -S --noconfirm --needed slurp

    sudo pacman -S --noconfirm --needed blueman
    sudo pacman -S --noconfirm --needed bluez
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service
}

function i_bunch() {
    sudo pacman -S --noconfirm --needed kitty
    sudo pacman -S --noconfirm --needed starship
    sudo pacman -S --noconfirm --needed kolourpaint
    sudo pacman -S --noconfirm --needed breeze
    sudo pacman -S --noconfirm --needed firefox
    sudo pacman -S --noconfirm --needed direnv
    sudo pacman -S --noconfirm --needed wofi
    sudo pacman -S --noconfirm --needed unrar
    sudo pacman -S --noconfirm --needed p7zip
    sudo pacman -S --noconfirm --needed lf
    sudo pacman -S --noconfirm --needed xclip
    sudo pacman -S --noconfirm --needed nemo
    sudo pacman -S --noconfirm --needed nemo-fileroller
    sudo pacman -S --noconfirm --needed wget
    sudo pacman -S --noconfirm --needed noto-fonts-cjk noto-fonts-emoji noto-fonts
    sudo pacman -S --noconfirm --needed yt-dlp
    sudo pacman -S --noconfirm --needed cronie
    # yay -S --noconfirm --answerdiff=None --needed visual-studio-code-bin
    yay -S --noconfirm --answerdiff=None --needed green-tunnel
    yay -S --noconfirm --answerdiff=None --needed sayonara-player
    yay -S --noconfirm --answerdiff=None --needed qbittorrent
    yay -S --noconfirm --answerdiff=None --needed parabolic

    # nemo_dir="$HOME/.local/share/nemo/actions"
    # nemo_file="helix.nemo_action"
    # nemo_file_path="$nemo_dir/$nemo_file"
    # mkdir -p "$nemo_dir"
    # cat <<EOF > "$nemo_file_path"
    # [Nemo Action]
    # Name=Open in Helix
    # Comment=Open the 'helix' editor in the selected folder
    # Exec=kitty tmux new-session -s "%p" "helix %F"
    # Icon-Name=Helix
    # Selection=any
    # Extensions=dir;
    # EOF
}

function i_nix() {
    # Nix->Docker. How do you even link static glibc in nix.
    sudo pacman -S --noconfirm --needed nix
    sudo systemctl enable --now nix-daemon.service
    sudo gpasswd -a $USER nix-users
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable
    nix-channel --update
    yay -S --noconfirm --answerdiff=None --needed nixpkgs-fmt # nix
    nix profile install nixpkgs#nil                  # nix
}

function s_locale() {
    sudo localectl set-locale LANG=en_GB.UTF-8
    sudo localectl set-locale LC_TIME=en_GB.UTF-8
    sudo localectl set-locale LC_NUMERIC=en_GB.UTF-8
    sudo localectl set-locale LC_MONETARY=en_GB.UTF-8
    sudo localectl set-locale LC_PAPER=en_GB.UTF-8
    sudo localectl set-locale LC_MEASUREMENT=en_GB.UTF-8
}

function s_theme() {
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
}

function i_docker() {
    sudo pacman -S --noconfirm --needed docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
}

function i_helix() {
    sudo pacman -S --noconfirm --needed helix
    sudo pacman -S --noconfirm --needed bat # live-grep script
    sudo pacman -S --noconfirm --needed tmux
    sudo pacman -S --noconfirm --needed fzf
    # LSPs and Formatters
    sudo pacman -S --noconfirm --needed prettier     # markdown etc.
    sudo pacman -S --noconfirm --needed pyright      # python
    sudo pacman -S --noconfirm --needed python-black # python
    sudo pacman -S --noconfirm --needed taplo        # toml file
    # yay -S --noconfirm --answerdiff=None --needed verible-git # verilog
}

function s_bashrc() {
    echo 'if [ -f ~/.config/my_bashrc ]; then . ~/.config/my_bashrc; fi' >> ~/.bashrc
}

# Check if any command-line arguments were provided
if [ $# -eq 0 ]; then
    i_network
    i_core
    i_yay
    i_qemu
    # i_vmware
    # i_nix
    i_nf
    i_wine_nvidia
    i_xremap
    i_y_core
    i_bunch
    i_docker
    i_helix
    s_locale
    s_theme
    s_bashrc
    reboot
fi

# Get the function name from the command line argument
function_name="$1"

# Call the specified function
case "$function_name" in
    "i_network")
        i_network
        ;;
    "i_nix")
        i_nix
        ;;
    *)
        echo "Invalid function name: $function_name"
        exit 1
        ;;
esac
