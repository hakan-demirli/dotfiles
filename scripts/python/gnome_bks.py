#!/usr/bin/env python3
"""
Edit gnome keyboard shortcuts.
    restore
    backup
    clean
"""
import os
import subprocess


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_DIR = os.path.join(SCRIPT_DIR, '../../config/')

BACKUP_FOLDER            = os.path.join(SCRIPT_DIR, 'gnome3-keybind-backup')
KEYBINDINGS_INPUT_FILE   = os.path.join(BACKUP_FOLDER, 'keybindings.dconf')
CUSTOM_VALUES_INPUT_FILE = os.path.join(BACKUP_FOLDER, 'custom-values.dconf')
CUSTOM_KEYS_INPUT_FILE   = os.path.join(BACKUP_FOLDER, 'custom-keys.dconf')

def backup_gnome3_keybindings():
    subprocess.run(['mkdir', '-p', BACKUP_FOLDER])
    subprocess.run(['dconf', 'dump', '/org/gnome/desktop/wm/keybindings/'], stdout=open(f'{KEYBINDINGS_INPUT_FILE}', 'w'))
    subprocess.run(['dconf', 'dump', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/'], stdout=open(f'{CUSTOM_VALUES_INPUT_FILE}', 'w'))
    subprocess.run(['dconf', 'read', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings'], stdout=open(f'{CUSTOM_KEYS_INPUT_FILE}', 'w'))
    print("Backup done.")

def restore_gnome3_keybindings():
    subprocess.run(['dconf', 'reset', '-f', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/'])
    subprocess.run(['dconf', 'reset', '-f', '/org/gnome/desktop/wm/keybindings/'])
    subprocess.run(['dconf', 'load', '/org/gnome/desktop/wm/keybindings/'], stdin=open(f'{KEYBINDINGS_INPUT_FILE}', 'r'))
    subprocess.run(['dconf', 'load', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/'], stdin=open(f'{CUSTOM_VALUES_INPUT_FILE}', 'r'))
    subprocess.run(['dconf', 'write', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings', subprocess.check_output(['cat', f'{CUSTOM_KEYS_INPUT_FILE}']).decode().strip()])
    print("Restore done.")

def clean_gnome3_keybindings():
    """use dconf-editor to find more if needed"""
    for i in range(0,11):
        subprocess.run(['gsettings', 'set', 'org.gnome.shell.keybindings', f'switch-to-application-{i}', '[]'])
        
if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("Usage: python script.py [backup|restore]")
        sys.exit(1)

    action = sys.argv[1]
    if action == 'backup':
        backup_gnome3_keybindings()
    elif action == 'restore':
        restore_gnome3_keybindings()
    elif action == 'clean':
        clean_gnome3_keybindings()
    else:
        print("Invalid action. Use [backup|restore].")

