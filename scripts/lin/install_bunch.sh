#!/bin/bash
# Update and upgrade packages
sudo pacman -Syu

# Install yay
sudo pacman -S --noconfirm --needed git
sudo pacman -S --noconfirm --needed base-devel
git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si

# Bunch of utility tools
sudo pacman -S --noconfirm --needed ntfs-3g
sudo pacman -S --noconfirm --needed gnome-disk-utility
sudo pacman -S --noconfirm --needed gnome-system-monitor
sudo pacman -S --noconfirm --needed drawing
sudo pacman -S --noconfirm --needed nemo-fileroller
sudo pacman -S --noconfirm --needed yt-dlp
sudo pacman -S --noconfirm --needed xclip
sudo pacman -S --noconfirm --needed cronie
sudo pacman -S --noconfirm --needed tmux
sudo pacman -S --noconfirm --needed kitty
sudo pacman -S --noconfirm --needed fzf
sudo pacman -S --noconfirm --needed wofi
sudo pacman -S --noconfirm --needed unrar
sudo pacman -S --noconfirm --needed p7zip
sudo pacman -S --noconfirm --needed ranger
sudo pacman -S --noconfirm --needed wget
sudo pacman -S --noconfirm --needed noto-fonts-cjk noto-fonts-emoji noto-fonts

# AGS
sudo pacman -S --noconfirm --needed typescript
sudo pacman -S --noconfirm --needed npm
sudo pacman -S --noconfirm --needed meson
sudo pacman -S --noconfirm --needed gjs
sudo pacman -S --noconfirm --needed gtk3
sudo pacman -S --noconfirm --needed gtk-layer-shell
sudo pacman -S --noconfirm --needed socat
sudo pacman -S --noconfirm --needed gnome-bluetooth-3.0
sudo pacman -S --noconfirm --needed upower
sudo pacman -S --noconfirm --needed networkmanager
sudo pacman -S --noconfirm --needed gobject-introspection
# Extra
sudo pacman -S --noconfirm --needed sassc
sudo pacman -S --noconfirm --needed brightnessctl
yay -S --noconfirm --answerdiff=None swww
yay -S --noconfirm --answerdiff=None asusctl
yay -S --noconfirm --answerdiff=None rog-control-center
#---
sudo pacman -S --noconfirm --needed slurp
sudo pacman -S --noconfirm --needed wf-recorder
sudo pacman -S --noconfirm --needed wl-gammactl
sudo pacman -S --noconfirm --needed pavucontrol
yay -S --noconfirm --answerdiff=None hyprshot
yay -S --noconfirm --answerdiff=None nwg-displays
yay -S --noconfirm --answerdiff=None wlr-randr
yay -S --noconfirm --answerdiff=None swaync

#---

#
sudo pacman -S --noconfirm --needed neovim

sudo pacman -S --noconfirm --needed blueman
sudo pacman -S --noconfirm --needed bluez
sudo systemctl start bluetooth.service

# yay -S input-remapper-git
# sudo systemctl restart input-remapper
# sudo systemctl enable input-remapper

sudo sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf
sudo pacman -Sy
sudo pacman -S --noconfirm --needed wine
sudo pacman -S --noconfirm --needed winetricks
sudo pacman -S --noconfirm --needed zenity
sudo pacman -S --noconfirm --needed lutris
sudo pacman -S --noconfirm --needed lib32-nvidia-utils
sudo pacman -S --noconfirm --needed xdg-desktop-portal-hyprland
sudo pacman -Rnsdd xdg-desktop-portal-gnome
yay -S --noconfirm --answerdiff=None visual-studio-code-bin
yay -S --noconfirm --answerdiff=None green-tunnel
yay -S --noconfirm --answerdiff=None sayonara-player
yay -S --noconfirm --answerdiff=None woeusb-ng
yay -S --noconfirm --answerdiff=None python-pyclip


# Install a Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.fonts
fc-cache -fv
rm JetBrainsMono.zip


# Install QEMU
sudo pacman -S --noconfirm --needed qemu-desktop
sudo pacman -S --noconfirm --needed dnsmasq
sudo pacman -S --noconfirm --needed virt-manager
sudo pacman -S --noconfirm --needed iptables-nft
sudo systemctl enable --now libvirtd
sudo gpasswd -a $USER libvirt
sudo gpasswd -a $USER kvm


# Set locale
sudo localectl set-locale LANG=en_GB.UTF-8
sudo localectl set-locale LC_TIME=en_GB.UTF-8
sudo localectl set-locale LC_NUMERIC=en_GB.UTF-8
sudo localectl set-locale LC_MONETARY=en_GB.UTF-8
sudo localectl set-locale LC_PAPER=en_GB.UTF-8
sudo localectl set-locale LC_MEASUREMENT=en_GB.UTF-8

# Run Scripts
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
python3 $SCRIPT_DIR/scripts/installation_scripts/ffcss.py

# Symlink configs
# Loop through folders inside $SCRIPT_DIR/config
for path in "$SCRIPT_DIR/config"/*; do
    # Check if the current item is a directory
    if [[ -d "$path" ]]; then
        # Extract the folder name
        folder_name=$(basename "$path")

        # Remove existing folder in ~/.config (if it exists)
        rm -rf "$HOME/.config/$folder_name"

        # Create a symbolic link to the folder
        ln -s "$path" "$HOME/.config/$folder_name"
    fi
done

# Include custom bashrc
code_snippet="# include .bashrc if it exists
if [ -f $SCRIPT_DIR/config/my_bashrc ]; then
    . $SCRIPT_DIR/config/my_bashrc
fi"
echo -e "$code_snippet" >> ~/.bashrc

# Give exectue permissions to all scripts which are in PATH
chmod +x $SCRIPT_DIR/scripts/*


gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty


systemctl daemon-reload && systemctl restart asusd
reboot


