#!/bin/bash
# Update and upgrade packages
sudo pacman -Syu

# Install yay
sudo pacman -S --noconfirm --needed git
sudo pacman -S --noconfirm --needed base-devel
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm

# Install the apps I use
sudo pacman -S --noconfirm xclip
sudo pacman -S --noconfirm cronie
sudo pacman -S --noconfirm tmux
sudo pacman -S --noconfirm kitty
sudo pacman -S --noconfirm fzf
sudo pacman -S --noconfirm expect
sudo pacman -S --noconfirm base-devel
sudo pacman -S --noconfirm python
sudo pacman -S --noconfirm python-virtualenv
sudo pacman -S --noconfirm python-pipx
sudo pacman -S --noconfirm python-pip
sudo pacman -S --noconfirm git
sudo pacman -S --noconfirm make
sudo pacman -S --noconfirm p7zip
sudo pacman -S --noconfirm unrar
sudo pacman -S --noconfirm unzip
sudo pacman -S --noconfirm jre8-openjdk
sudo pacman -S --noconfirm alacarte
sudo pacman -S --noconfirm kolourpaint
sudo pacman -S --noconfirm gdb
sudo pacman -S --noconfirm nemo
sudo pacman -S --noconfirm ffmpeg
sudo pacman -S --noconfirm wget
sudo pacman -S --noconfirm net-tools
sudo pacman -S --noconfirm flex
sudo pacman -S --noconfirm ncurses
sudo pacman -S --noconfirm dtc
sudo pacman -S --noconfirm libnotify
sudo pacman -S --noconfirm ntfs-3g
sudo pacman -S --noconfirm nemo-fileroller
sudo pacman -S --noconfirm breeze
sudo pacman -S --noconfirm qgnomeplatform-qt5
sudo pacman -S --noconfirm dconf-editor
sudo pacman -S --noconfirm wine
sudo pacman -S --noconfirm lutris
sudo pacman -S --noconfirm yt-dlp
sudo pacman -S --noconfirm --needed nvidia
sudo pacman -S --noconfirm --needed nvidia-utils
sudo pacman -S --noconfirm --needed lib32-nvidia-utils
sudo pacman -S --noconfirm --needed nvidia-settings
sudo pacman -S --noconfirm --needed vulkan-icd-loader
sudo pacman -S --noconfirm --needed lib32-vulkan-icd-loader
sudo yay -S --noconfirm --answerdiff=None green-tunnel
sudo yay -S --noconfirm --answerdiff=None sayonara-player
sudo yay -S --noconfirm --answerdiff=None woeusb-ng


# Install a Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.fonts
fc-cache -fv
rm JetBrainsMono.zip


# Install QEMU
sudo pacman -S --noconfirm qemu-desktop
sudo pacman -S --noconfirm dnsmasq
sudo pacman -S --noconfirm virt-manager
sudo pacman -S --noconfirm iptables-nft
sudo systemctl enable --now libvirtd
sudo gpasswd -a $USER libvirt
sudo gpasswd -a $USER kvm


# Install neovim
wget https://github.com/neovim/neovim/releases/download/stable/nvim.appimage
mkdir -p ~/.local/bin
mv ./nvim.appimage ~/.local/bin/nvim
chmod +x ~/.local/bin/nvim
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'alias vi="nvim"' >> ~/.bashrc
echo 'alias vim="nvim"' >> ~/.bashrc
rm ./nvim.appimage

# Set nemo default file explorer
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search
gsettings set org.gnome.desktop.background show-desktop-icons false
gsettings set org.nemo.desktop show-desktop-icons true

# Set default terminal
sudo ln -sf $(which kitty) /usr/bin/x-terminal-emulator
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
gsettings set org.gnome.desktop.default-applications.terminal exec kitty

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
rm -rf ~/.config/kitty
ln -s $SCRIPT_DIR/config/kitty ~/.config/kitty
rm -rf ~/.config/nvim
ln -s $SCRIPT_DIR/config/nvim ~/.config/nvim

# Install Video and Audio Codecs
sudo pacman -S --noconfirm jasper lame libdca libdv gst-libav libtheora libvorbis libxv wavpack x264 xvidcore dvd+rw-tools dvdauthor dvgrab libmad libmpeg2 libdvdcss libdvdread libdvdnav exfat-utils fuse-exfat a52dec faac faad2 flac
sudo pacman -S --noconfirm ffmpeg
sudo pacman -S --noconfirm gst-plugins-ugly
sudo pacman -S --noconfirm gst-libav
sudo pacman -S --noconfirm gst-plugins-good
sudo pacman -S --noconfirm gst-plugins-bad
sudo pacman -S --noconfirm gst-plugins-base

# Include custom bashrc
code_snippet="# include .bashrc if it exists
if [ -f $SCRIPT_DIR/config/my_bashrc ]; then
    . $SCRIPT_DIR/config/my_bashrc
fi"
echo -e "$code_snippet" >> ~/.bashrc

# Give exectue permissions to all scripts which are in PATH
chmod +x $SCRIPT_DIR/scripts/*




# Add open with neovim action to nemo right click menu

cd ~/.local/share/nemo/actions
touch code.nvim.nemo_action

cat << EOF > code.nvim.nemo_action
[Nemo Action]
Name=Open in Neovim
Comment=Open the folder in 'nvim' editor
Exec=kitty -e nvim %F
Icon-Name=Neovim
Selection=any
Extensions=dir;
EOF


wget https://raw.github.com/nwg-piotr/nwg-shell/main/install/arch.sh && chmod u+x arch.sh && ./arch.sh && rm arch.sh



