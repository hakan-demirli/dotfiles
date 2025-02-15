# choco install -y green-tunnel-gui

# winget install -e --id Valve.Steam        # I don't need
# winget install -e --id Lexikos.AutoHotkey # Get an exe
# winget install -e --id Guru3D.Afterburner # Get an exe
# winget install -e --id Rufus.Rufus        # Get an exe
# winget install -e --id Kitware.CMake      # dont bother. Use wsl

# dependencies
winget install -e --id Microsoft.DotNet.Runtime.7
winget install -e --id Microsoft.VCRedist.2015+.x86
winget install -e --id Microsoft.VCRedist.2015+.x64
winget install -e --id Microsoft.DotNet.DesktopRuntime.7
winget install -e --id Microsoft.DotNet.DesktopRuntime.3_1
winget install -e --id Microsoft.DirectX
winget install -e --id Gyan.FFmpeg
winget install -e --id yt-dlp.yt-dlp
winget install -e --id=AppWork.JDownloader
# winget install -e --id=valinet.ExplorerPatcher
# winget install -e --id=StartIsBack.StartAllBack
# Browsers, tools, development
# winget install -e --id Discord.Discord
# winget install -e --id Mozilla.Firefox
winget install -e --id TorProject.TorBrowser
winget install -e --id 7zip.7zip
# winget install -e --id Microsoft.WindowsTerminal

winget install -e --id Git.Git
# winget install -e --id Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'
# winget install -e --id Neovim.Neovim
winget install -e --id Helix.Helix
winget install -e --id qBittorrent.qBittorrent
winget install -e --id Microsoft.PowerToys
winget install -e --id AIMP.AIMP
winget install -e --id AntibodySoftware.WizTree
winget install -e --id Python.Python.3.11


# winget install -e --id JohnMacFarlane.Pandoc -v 2.19.2
# winget pin add --id JohnMacFarlane.Pandoc --blocking
