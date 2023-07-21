#!/bin/bash

sudo apt update
sudo apt upgrade

sudo apt-get -y install python3
sudo apt-get -y install python3-venv
sudo apt-get -y install python3-pip
sudo apt-get -y install nemo
sudo apt-get -y install alacarte
sudo apt-get -y install gnome-themes-extra
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

pip install pycairo








