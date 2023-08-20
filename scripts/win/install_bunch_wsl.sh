#!/usr/bin/env bash

sudo apt-get update
sudo apt-get upgrade

sudo apt-get -y install x11-apps
sudo apt-get -y install python3
sudo apt-get -y install python3-venv
sudo apt-get -y install python3-pip
sudo apt-get -y install build-essential




sudo apt-get -y install alacarte
pip install pycairo # dependency


sudo apt-get -y install gnome-themes-extra
sudo apt-get -y install gnome-tweaks

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme prefer-dark



echo -e "alias nemo='explorer.exe'\n" >> ~/.bashrc
