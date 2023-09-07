#!/usr/bin/env bash

# Update and upgrade packages
sudo pacman -Syu

# Install yay
sudo pacman -S --noconfirm --needed git
sudo pacman -S --noconfirm --needed base-devel
git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si

# Change the MAKEFLAGS value to use all available cores
sudo sed -i '/^#MAKEFLAGS=/s/^#//' /etc/makepkg.conf
sudo sed -i 's/^MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

# Applications
sudo pacman -S --noconfirm --needed kitty
sudo pacman -S --noconfirm --needed drawing
sudo pacman -S --noconfirm --needed firefox
sudo pacman -S --noconfirm --needed discord
sudo pacman -S --noconfirm --needed nemo
sudo pacman -S --noconfirm --needed nemo-fileroller
yay -S --noconfirm --answerdiff=None visual-studio-code-bin
yay -S --noconfirm --answerdiff=None green-tunnel
yay -S --noconfirm --answerdiff=None sayonara-player
yay -S --noconfirm --answerdiff=None qbittorrent



# Bunch of utility tools
sudo pacman -S --noconfirm --needed ntfs-3g
sudo pacman -S --noconfirm --needed gnome-disk-utility
sudo pacman -S --noconfirm --needed gnome-system-monitor
sudo pacman -S --noconfirm --needed yt-dlp
sudo pacman -S --noconfirm --needed xclip
sudo pacman -S --noconfirm --needed cronie
sudo pacman -S --noconfirm --needed tmux
sudo pacman -S --noconfirm --needed fzf
sudo pacman -S --noconfirm --needed wofi
sudo pacman -S --noconfirm --needed unrar
sudo pacman -S --noconfirm --needed p7zip
sudo pacman -S --noconfirm --needed ranger
sudo pacman -S --noconfirm --needed wget
sudo pacman -S --noconfirm --needed noto-fonts-cjk noto-fonts-emoji noto-fonts

sudo pacman -S --noconfirm --needed waybar
sudo pacman -S --noconfirm --needed gtk3
sudo pacman -S --noconfirm --needed gtk-layer-shell
sudo pacman -S --noconfirm --needed socat
sudo pacman -S --noconfirm --needed gnome-bluetooth-3.0
sudo pacman -S --noconfirm --needed gnome-power-manager
sudo pacman -S --noconfirm --needed upower
sudo pacman -S --noconfirm --needed networkmanager
sudo pacman -S --noconfirm --needed network-manager-applet
sudo pacman -S --noconfirm --needed brightnessctl
sudo pacman -S --noconfirm --needed polkit-gnome
sudo pacman -S --noconfirm --needed gnome-keyring
sudo pacman -S --noconfirm --needed pavucontrol
sudo pacman -S --noconfirm --needed ffmpeg
sudo pacman -S --noconfirm --needed tk
sudo pacman -S --noconfirm --needed yt-dlp
sudo pacman -S --noconfirm --needed gnome-themes-extra
sudo pacman -S --noconfirm --needed adwaita-qt5
sudo pacman -S --noconfirm --needed adwaita-qt6
sudo pacman -S --noconfirm --needed swayidle

sudo pacman -S --noconfirm --needed blueman
sudo pacman -S --noconfirm --needed bluez
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service


yay -S --noconfirm --answerdiff=None swww
yay -S --noconfirm --answerdiff=None asusctl
yay -S --noconfirm --answerdiff=None rog-control-center
yay -S --noconfirm --answerdiff=None hyprshot
yay -S --noconfirm --answerdiff=None nwg-displays
yay -S --noconfirm --answerdiff=None wlr-randr
yay -S --noconfirm --answerdiff=None wlr-randr
yay -S --noconfirm --answerdiff=None woeusb-ng
yay -S --noconfirm --answerdiff=None swaync
yay -S --noconfirm --answerdiff=None gtklock


yay -S --noconfirm --answerdiff=None xremap-hypr-bin
sudo gpasswd -a $USER input
echo 'KERNEL=="uinput", GROUP="input", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-input.rules

# Windows Emulation/Layer
sudo sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf
sudo pacman -Syu
sudo pacman -S --noconfirm --needed wine
sudo pacman -S --noconfirm --needed winetricks
sudo pacman -S --noconfirm --needed zenity
sudo pacman -S --noconfirm --needed lutris
sudo pacman -S --noconfirm --needed lib32-nvidia-utils
sudo pacman -S --noconfirm --needed xdg-desktop-portal-hyprland
sudo pacman -S --noconfirm --needed nvidia
sudo pacman -S --noconfirm --needed nvidia-prime


# Install a Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
mkdir -p ~/.fonts
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

######## CONFIGS #############
# Set locale
sudo localectl set-locale LANG=en_GB.UTF-8
sudo localectl set-locale LC_TIME=en_GB.UTF-8
sudo localectl set-locale LC_NUMERIC=en_GB.UTF-8
sudo localectl set-locale LC_MONETARY=en_GB.UTF-8
sudo localectl set-locale LC_PAPER=en_GB.UTF-8
sudo localectl set-locale LC_MEASUREMENT=en_GB.UTF-8

# Set Theme
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Set default apps
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search
xdg-settings set default-web-browser firefox.desktop

# Create a custom context item for Nemo
nemo_dir="$HOME/.local/share/nemo/actions"
nemo_file="helix.nemo_action"
nemo_file_path="$nemo_dir/$nemo_file"
mkdir -p "$nemo_dir"
cat <<EOF > "$nemo_file_path"
[Nemo Action]
Name=Open in Helix
Comment=Open the 'helix' editor in the selected folder
Exec=kitty tmux new-session -s "%p" "helix %F"
Icon-Name=Helix
Selection=any
Extensions=dir;
EOF


sudo pacman -S --noconfirm --needed nix
sudo systemctl enable --now nix-daemon.service
sudo gpasswd -a $USER nix-users
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update


# Editor
sudo pacman -S --noconfirm --needed helix
sudo pacman -S --noconfirm --needed bat # live-grep script
# LSPs and Formatters
sudo pacman -S --noconfirm --needed prettier     # markdown etc.
sudo pacman -S --noconfirm --needed pyright      # python
sudo pacman -S --noconfirm --needed python-black # python
sudo pacman -S --noconfirm --needed taplo        # toml file
yay -S --noconfirm --answerdiff=None verible-git # verilog
yay -S --noconfirm --answerdiff=None nixpkgs-fmt # nix
nix profile install nixpkgs#nil                  # nix

echo 'if [ -f ~/.config/my_bashrc ]; then . ~/.config/my_bashrc; fi' >> ~/.bashrc

# systemctl daemon-reload && systemctl restart asusd
reboot
