#!/usr/bin/env bash
# shellcheck source=/dev/null

sudo apt-get update -y
sudo apt-get upgrade -y

# Install the apps I use
sudo snap install yazi --classic

sudo apt-get -y install fzf
sudo apt-get -y install kitty
sudo apt-get -y install tmux
sudo apt-get -y install gnome-shell-extension-manager
sudo apt-get -y install gnome-tweaks
sudo apt-get -y install build-essential
sudo apt-get -y install gdb
sudo apt-get -y install python3
sudo apt-get -y install python3-venv
sudo apt-get -y install python3-pip
sudo apt-get -y install git
sudo apt-get -y install git-crypt
sudo apt-get -y install make
sudo apt-get -y install crontab
sudo apt-get -y install expect
sudo apt-get -y install p7zip-full
sudo apt-get -y install p7zip
sudo apt-get -y install p7zip-rar
sudo apt-get -y install unrar
sudo apt-get -y install default-jre
sudo apt-get -y install alacarte
sudo apt-get -y install kolourpaint
sudo apt-get -y install nemo
sudo apt-get -y install ffmpeg
sudo apt-get -y install wget
sudo apt-get -y install curl
sudo apt-get -y install gnome-shell-extensions
sudo apt-get -y install net-tools
sudo apt-get -y install libfl-dev
sudo apt-get -y install libncursesw5
sudo apt-get -y install device-tree-compiler
sudo apt-get -y install libnotify-bin

# Install a Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.fonts
fc-cache -fv
rm JetBrainsMono.zip

# Set theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

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
sudo apt-get -y purge byobu
sudo apt-get -y purge gnome-todo
sudo apt-get -y purge rhythmbox
sudo apt-get -y purge shotwell
sudo apt-get -y purge gnome-music
sudo apt-get -y purge gnome-terminal

# set default terminal
sudo update-alternatives --set x-terminal-emulator "$(which kitty)"
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
gsettings set org.gnome.desktop.default-applications.terminal exec kitty

# set locale
sudo locale-gen en_GB
sudo locale-gen en_GB.UTF-8
sudo update-locale

# Symlink all files/directories from ~/Desktop/dotfiles/.config/ to ~/.config/
for item in ~/Desktop/dotfiles/.config/*; do
  ln -sfn "$item" ~/.config/
done

# Install Docker
sudo apt-get update -y
sudo apt-get -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker "$USER"

# Install nix: user interaction
sh <(curl -L https://nixos.org/nix/install) --daemon

# install propriatery stuff: user interaction
sudo apt-get -y install ubuntu-restricted-extras

echo -e "\e[31mYOU SHOULD REBOOT\e[0m"
