
# choco install -y vcredist140
# choco install -y green-tunnel-gui
# choco install -y powertoys
# choco install -y autoruns
# choco install -y sudo

# winget install -e --id Valve.Steam        # I don't need
# winget install -e --id MusicBee.MusicBee  # unexpected error. I use AIMP instead
# winget install -e --id Lexikos.AutoHotkey # not found
# winget install -e --id Guru3D.Afterburner # unexpected error
# winget install -e --id Rufus.Rufus        # Buggy
winget install -e --id Microsoft.DotNet.Runtime.7
winget install -e --id Mozilla.Firefox
winget install -e --id TorProject.TorBrowser
winget install -e --id Anaconda.Miniconda3
winget install -e --id Git.Git
winget install -e --id Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'
winget install -e --id Kitware.CMake
winget install -e --id 7zip.7zip
winget install -e --id qBittorrent.qBittorrent
winget install -e --id Microsoft.VCRedist.2015+.x86
winget install -e --id Microsoft.VCRedist.2015+.x64
winget install -e --id Microsoft.DotNet.DesktopRuntime.3_1
winget install -e --id Microsoft.DotNet.DesktopRuntime.7
winget install -e --id Microsoft.WindowsTerminal
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id AIMP.AIMP
winget install -e --id Microsoft.DirectX
winget install -e --id Microsoft.PowerToys


