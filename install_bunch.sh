#!/bin/bash

sudo apt-get update  -y
sudo apt-get upgrade -y


# Install the apps I use
sudo apt-get -y install crontab
sudo apt-get -y install sayonara
sudo apt-get -y install neovim
sudo apt-get -y install tmux
sudo apt-get -y install kitty
sudo apt-get -y install fzf
sudo apt-get -y install zsh
sudo apt-get -y install gnome-shell-extension-manager
sudo apt-get -y install expect
sudo apt-get -y install gnome-tweaks
sudo apt-get -y install build-essential
sudo apt-get -y install python3
sudo apt-get -y install python3-venv
sudo apt-get -y install python3-pip
sudo apt-get -y install git
sudo apt-get -y install make
sudo apt-get -y install p7zip-full
sudo apt-get -y install p7zip
sudo apt-get -y install p7zip-rar
sudo apt-get -y install unrar
sudo apt-get -y install default-jre
sudo apt-get -y install alacarte
sudo apt-get -y install kolourpaint
sudo apt-get -y install gdb
sudo apt-get -y install nemo
sudo apt-get -y install ffmpeg
sudo apt-get -y install wget
sudo apt-get -y install gnome-shell-extensions
sudo apt-get -y install net-tools
sudo apt-get -y install libfl-dev
sudo apt-get -y install libncursesw5
sudo apt-get -y install device-tree-compiler
# Install green tunnel
wget https://github.com/SadeghHayeri/GreenTunnel/releases/download/v1.8.3/green-tunnel-debian.zip
unzip green-tunnel-debian.zip
sudo apt-get -y install ./green-tunnel_1.7.5_amd64.deb

# Install themes, fonts and icons
sudo apt-get -y install breeze
sudo apt-get -y install adwaita-icon-theme-full
sudo apt-get -y install yaru-theme-gtk 
sudo apt-get -y install yaru-theme-sound
sudo apt-get -y install yaru-theme-gnome-shell
sudo apt-get -y install yaru-theme-icon
sudo apt-get -y install yaru-theme-unity
# Install a Nerd Font
echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
unzip DroidSansMono.zip -d ~/.fonts
fc-cache -fv
rm JetBrainsMono.zip


# Install pip applications
sudo pip3 install WoeUSB-ng


# Install QEMU
sudo apt-get -y install  qemu-kvm
sudo apt-get -y install  libvirt-daemon-system
sudo apt-get -y install  libvirt-clients
sudo apt-get -y install  bridge-utils
sudo adduser $USER libvirt
sudo adduser $USER kvm
sudo systemctl enable --now libvirtd
sudo apt-get -y install virt-manager

# Intel GPU Tools
# sudo apt-get -y install intel-gpu-tools


# Remove Games
sudo apt-get -y purge aisleriot
sudo apt-get -y purge gnome-sudoku
sudo apt-get -y purge gbrainy
sudo apt-get -y purge gnome-sushi
sudo apt-get -y purge gnome-taquin
sudo apt-get -y purge gnome-tetravex
sudo apt-get -y purge mahjongg
sudo apt-get -y purge gnome-robots
sudo apt-get -y purge ace-of-penguins
sudo apt-get -y purge gnome-chess
sudo apt-get -y purge lightsoff 
sudo apt-get -y purge swell-foop
sudo apt-get -y purge quadrapassel 
sudo apt-get -y purge five-or-more 
sudo apt-get -y purge four-in-a-row
sudo apt-get -y purge hitori
sudo apt-get -y purge tali
sudo apt-get -y purge iagno
sudo apt-get -y purge gnome-2048
sudo apt-get -y purge gnome-klotski
sudo apt-get -y purge gnome-mines
sudo apt-get -y purge gnome-nibbles
sudo apt-get -y purge gnome-mahjongg 

# Remove Unused Apps
sudo apt-get -y purge nautilus
sudo apt-get -y purge byobu
sudo apt-get -y purge gnome-todo
sudo apt-get -y purge rhythmbox
sudo apt-get -y purge shotwell
sudo apt-get -y purge gnome-music
sudo apt-get -y purge gnome-terminal


# Set nemo default fileexplorer
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search
gsettings set org.gnome.desktop.background show-desktop-icons false
gsettings set org.nemo.desktop show-desktop-icons true


# set default shell
chsh -s $(which zsh)


# set default terminal
sudo update-alternatives --set x-terminal-emulator "$(which kitty)"
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
gsettings set org.gnome.desktop.default-applications.terminal exec kitty

# set locale
sudo locale-gen en_GB
sudo locale-gen en_GB.UTF-8
sudo update-locale


# Run Scripts
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
python3 $SCRIPT_DIR/scripts/installation_scripts/n2o.py
python3 $SCRIPT_DIR/scripts/installation_scripts/ffcss.py
python3 $SCRIPT_DIR/scripts/installation_scripts/gnome_bks.py restore


# Requires EULA, user interaction
sudo apt-get -y install ubuntu-restricted-extras







reboot

