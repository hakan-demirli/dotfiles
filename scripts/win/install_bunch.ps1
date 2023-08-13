
# choco install -y green-tunnel-gui

# winget install -e --id Valve.Steam        # I don't need
# winget install -e --id Lexikos.AutoHotkey # Get an exe
# winget install -e --id Guru3D.Afterburner # Get an exe
# winget install -e --id Rufus.Rufus        # Get an exe
# winget install -e --id Gyan.FFmpeg        # Get an exe
# winget install yt-dlp                     # Get an exe

# dependencies
winget install -e --id Microsoft.DotNet.Runtime.7
winget install -e --id Microsoft.VCRedist.2015+.x86
winget install -e --id Microsoft.VCRedist.2015+.x64
winget install -e --id Microsoft.DotNet.DesktopRuntime.7
winget install -e --id Microsoft.DotNet.DesktopRuntime.3_1
winget install -e --id Microsoft.DirectX
winget install -e --id OpenJS.NodeJS.LTS

# Browsers, tools, development
winget install -e --id Mozilla.Firefox
winget install -e --id TorProject.TorBrowser
winget install -e --id 7zip.7zip
winget install -e --id Microsoft.WindowsTerminal
# winget install -e --id Anaconda.Miniconda3
winget install -e --id Git.Git
winget install -e --id Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'
winget install -e --id Neovim.Neovim
winget install -e --id Kitware.CMake
winget install -e --id qBittorrent.qBittorrent
winget install -e --id Microsoft.PowerToys
winget install -e --id AIMP.AIMP

# Install Install Visual Studio with C++ Desktop dev kit.
# Install Cuda toolkit

