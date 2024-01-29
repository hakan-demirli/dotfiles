* **Hide context menu entry**
    * Open regedit.exe and visit \HKEY_CLASSES_ROOT\PackagedCom\ClassIndex\. There should be several tens of entries (keys) under that, all named after {UUID}.
    * Expand all entries you saw in Step 1 and look for the entry containing keyword AdvancedMicroDevicesInc (AMD). Once you find it, copy its corresponding UUID string.
    * visit \HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\. There should be three keys under Shell Extensions: Approved, Blocked, and Cached. If there is no Blocked key on your system, manually create it by right-clicking Shell Extensions, and create a new key named Blocked.
    * Enter Blocked key (which appears as a directory in regedit tool). Under directory Blocked, create a new String (aka type REG_SZ). Rename the String as {UUID}, in which UUID is the same UUID as we found in Step 2.

* **Stop driver update for a specific hardware**
    * Find Hardware ID of your graphic adapter in Device Manager - Graphic Adapters - Your graphic card, and copy the 2nd line of the four shown under Details - Hardware IDs.
    * Open Group Policy Editor (gpedit.msc)
    * Navigate to Computer Configuration - Administrative Templates - System - Device Installation - Device Installation Restrictions
    * Double click Prevent Installation of devices that match any of these device IDs
    * Tick Enabled and click Show
    * Enter the Hardware ID in a value line
    * Confirm any open windows (most likely OK)

* **/mnt/c/Windows/Explorer.exe: cannot execute binary file: Exec format error**
    * Run the following commands in order:
        ```
        wsl> sudo apt install binfmt-support
        wsl> sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /usr/lib/binfmt.d/WSLInterop.conf'
        wsl> exit
        powershell> wsl --shutdown
        powershell> wsl
        wsl> /mnt/c/WINDOWS/explorer.exe
        ```

* **Hyprv how to share folders**
    * Do not login in the default screen.
    * Click to enchanced session when login screen pops up. Then login from there.
    * ```sudo apt-get install x2goserver```

* **Hyprv enchanced session blue screen**
    * Do not login in the default screen.
    * Click to enchanced session when login screen pops up. Then login from there.
    * ```sudo apt-get install x2goserver```

* **How to backup/restore WSL**
    * List installed:
        * ```wsl --list --verbose```
    * Export it:
        * ```wsl --export Ubuntu D:/backups/Ubuntu_backup.tar```
    * Import tar:
        * ```wsl --import Ubuntu D:/wsl D:/backups/Ubuntu_backup.tar```
    * Import vhdx:
        * ```wsl --import-in-place Ubuntu D:/backups/Ubuntu_backup.vhdx```
    * Delete it:
        * ```wsl.exe --unregister Ubuntu```

* **Exported and imported WSL user became root**
    *  Set default user by adding the below entry to /etc/wsl.conf
    ```
    [user]
        default=emre
    ```

* **How to Delete the EFI System Partition**
    * EaseUS Partition Master Free

- **How to create windows shortcut for wsl application**
    * So to create a Windows Start Menu item, just create a corresponding `/usr/share/applications/.desktop':
    ```bash
    sudo bash -c 'cat << EOF > /usr/share/applications/<appname>.desktop
    [Desktop Entry]
    Type=Application
    Name=<appname>
    Exec=/path/to/app
    EOF'
    ```

* **WSL2 Dconf error/warning**
    * Reboot
    * try again
    * Install gnome-tweaks
    * Add this to bash: `export DISPLAY=:0`
    * try again
    * Reboot
    * remove this from bash: `export DISPLAY=:0`
    * Reboot
    * try again

* **Change line endings recursively crlf (line endings/\r\n)**
    * Install git and git bash.
        * ```find ./ -type f -print0 | xargs -0 dos2unix --```
    * Or install wsl and same command

- **Scan for bad sectors**
    * HD Tune Pro

- **How to get hardware device names from disk manager**
	* ```Get-PhysicalDisk | Where-Object MediaType -eq 'SSD' | Select-Object DeviceID, FriendlyName```
	* This will give you the ids of the disks and disk hardware names. Then you can lookup the drive letters in disk manager.

- **Copy a file to shell:startup**
    * ```copy "%ALLUSERSPROFILE%\Desktop\AaRM.bat" "%USERPROFILE%\Start Menu\Programs\Startup"```

- **Run python app at login, startup**
    * Create a cmd file with the follwing content and add it to startup folder Win+R (shell:startup)
        * python path\to\your\script.py

- **Windows 10 style start menu and vertical taskbar for Windows 11**
    * https://github.com/valinet/ExplorerPatcher

- **Overclock monitor (display/refresh rate/Hz/cru)**
    * These suggestions are special to my Lenovo L340 laptop.
    * Download CRU old version prefereably (1.4.2)
        * ```https://www.monitortests.com/forum/Thread-Custom-Resolution-Utility-CRU```
    * Use reduced timings and don't pass 240Hz pixel clock.

- **Windirstat faster alternative(Free/storage/size/bloat)**
    * WizTree

* **How to enable Hypr-v**
    * Turn on windows features on/off
        * Hyprv
        * Windows sandbox

* **How to assign a key to another key/key combination**
    * Permanent:
        * [SharpKeys](https://www.randyrants.com/category/sharpkeys/)
    * Temp:
        * AutoHotKey

* **Invert icon file using ffmpeg**
    * ```ffmpeg -i gear.ico gear.png```
    * ```ffmpeg -i gear.png -vf "negate" inverted_gear.png```
    * ```ffmpeg -i inverted_gear.png -s 256x256 gear_inverted.ico```

* **Duplicate file finder**
    * 1st option:
        * CCleaner Portable.
    * 2nd option:
        * WSL + Bash script.
    * 3rd option:
        * [czkawka](https://github.com/qarmin/czkawka)

* **How to make taskbar thinner (vertical)**
    * Unlock the taskbar (right-click on taskbar > unlock the taskbar) and put it on the left or right
    * Enable small taskbar buttons
    * Download 7+ taskbar tweaker. It's open source.
    * Install 7+ taskbar tweaker and run it
    * On the system tray, find the icon 7+ taskbar tweaker and right click on it
    * select advanced settings
    * Find the string 'no_width_limit' and change the value from 0 to 1.
    * Now you can shrink the taskbar further.
    * logout or reboot. Make sure to run 7+ taskbar tweaker on startup.
    * Enjoy!

* **How to cap frame rate outside of the game**
    * Use RTSS: Riva tuner server statics.

* **Custom Windows no bloatware**
    * https://github.com/Atlas-OS/Atlas

* **Open Source Portable Camera App**
    * https://webcamoid.github.io/

* **Portable Screen Recorder**
    * https://github.com/jeffijoe/screengun

* **Enable Two Finger Tap Right Click(L340)**
    * Browse the location `HKEY_LOCAL_MACHINE\SOFTWARE\Synaptics\SynTP\Win10` in registry.
    * Double click on 2FingerTapAction and change the value to 2.
    * Log-out or restart

* **Execution of scripts is disabled on this system**
    * Enable scripts:
        * `Set-ExecutionPolicy RemoteSigned`
        * `Set-ExecutionPolicy unrestricted`
    * Disable again:
        * `Set-ExecutionPolicy Restricted`

* **Add Open Windows Terminal Here Option to Right-click Menu**
    * Open Windows Terminal settings
    * Open the settings.json
    * Add `"startingDirectory": "."` to the profiles section:
        ```json
            {
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": false,
                "name": "Windows PowerShell",
                "startingDirectory": "."
            },
        ```
    * Change the username and run this registry script:
        ```R
            Windows Registry Editor Version 5.00
            [HKEY_CLASSES_ROOT\Directory\Background\shell\wt]
            @="Open Windows Terminal here"
            [HKEY_CLASSES_ROOT\Directory\Background\shell\wt\command]
            @="C:\\Users\\<UserName>\\AppData\\Local\\Microsoft\\WindowsApps\\wt.exe"
        ```
    * (Optional) Add an icon to the right click menu
        * Download the icon you want: `terminal.ico`
        * Put it here: `%USERPROFILE%/AppData/Local/WTerminal`
        * Open the following folder in regedit: `HKEY_CLASSES_ROOT\Directory\Background\shell\wt`
        * Add a new string value and name it `Icon`
        * Change the value to `%USERPROFILE%/AppData/Local/WTerminal/terminal.ico`

* **Print enviroment variable via PowerShell**
    * ```$env:MYVARIABLE```

* **Add enviroment variable via PowerShell**
    * ```$env:MYVARIABLE = 'whatever'```

* **Remove default Python from path**
    * Open App execution aliases
        * Toggle all python realated things to off

* **How to add an app to start menu manually**
    * Copy the shortcut here or here
        <!--* `%AppData%\Microsoft\Windows\Start Menu\Programs`-->
        * `C:\ProgramData\Microsoft\Windows\Start Menu\Programs`
    * Go to your "All apps" list under the Start button
    * Right click on this file from the "Apps list" and click "Pin to start".

* **How to enable Themes:**
    1. cmd: sc config Themes start=auto
    2. Restart
    3. get a theme (find one online)
    4. Copy to C:\Windows\Resources\Themes
    5. use https://github.com/namazso/SecureUxTheme
    6. Double click the theme in C:\Windows\Resources\Themes
    7. Penumbra10s

* **SSH**
    * Install the OpenSSH Client
        * ```Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0```
    * Install the OpenSSH Server
        * ```Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0```

* **How to run app at startup**
    * Create a shortcut to the exe.
    * Paste it here:
        * Windows logo key  + R, type shell:startup, then select OK.

* **Can't install Windows Terminal from Github(msix/bundle)**
    * Use microsoft store

* **How to access EXT4 Linux Partition**
    * Diskinternals

* **How to find a memory leak**
    * https://superuser.com/questions/949244/windows-10-high-memory-usage-unknown-reason

* **Unable to launch Vulkan apps/game on notebooks with AMD Radeon iGPUs**
    * Check if there is a newer AMD Radeon GPU driver for your notebook. If so, proceed to update the driver.
    *  Add a new env variable:
        * View Advanced System Settigns > Environment Variables > System variables > New..
            * Variable name: DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1
            * Variable value: 1

* **Ranger alternative**
    * lf
    * [dotfiles](https://github.com/Goxore/dotfiles/tree/main/configs/.config/lf)

* **Remove the duplicate entires of the Operating Systems from the boot manager?**
    * msconfig > boot tab
        * Identify the default or the current Operating System and delete the other one.

* **Open Source Asus Armor Create Alternative**
    * [GHelper](https://github.com/seerge/g-helper)

* **Open a new tab in the running instance of Windows Terminal**
    * wt settings -> Startup -> Attach to the most rececently used.

* **Usable partition manager**
    * EaseUS Partition Master Free

* **Windhawk**
    * The customization marketplace for Windows programs

* **Docker vscode instance**
    * Open WSL and go to a folder.
        * ```code .```
        * Ctrl+shift+p > new container > Ubuntu
        * follow along
    * To reopen it just go to the same folder and `code .`
    * Don't use docker desktop dev environments. Git ssh and login is wonky. Missing user account.

* **AMD IGPU Code 43**
    * When:
        * Started after closing the lid without manually shutting down on Linux.
           * PC didn't sleep for some reason.
           * After using laptop for an hour and rebooting Hyprland crashed.
           * On Windows Code 43 appeared.
    * Solution:
        * Plug off your laptop from AC.
        * Reboot.
        * Plug it back in.
        * Remove AMD drivers using `amdcleanuputility.exe`
        * Remove Nvidia drivers.
        * Reboot couple of times.
        * Plug off your laptop from AC.
        * Reboot couple more.
        * Install drivers couple of times and remove them.
        * IDK somewhere along the way it should be gone.

| Default Shortcuts  | Description                   |
| -----------        | -----------                   |
| `Windows + D`      | reveals your desktop          |
|`Control + T   `| opens new tab                     |
|`Control + T   `| opens new tab                     |
|`Control + w   `| closes the tab                    |
|`Control + tab `| change tab                        |
|`alt + space               `| rofi/wofi like run menu                               |
|`Control + right/left arrow`| jump to end/start of the word                         |
|`Control + end/home        `| move  text cursor to the  top or  bottom of the page. |
|`Windowskey + space`        | keyboard switch short cut.                            |
|`Windowskey + tab  `        | taskview                                              |

