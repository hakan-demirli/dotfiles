# Set the execution policy and update security protocol
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Install Chocolatey
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install packages using Chocolatey
choco install -y firefox
choco install -y msiafterburner
choco install -y dotnet-7.0-desktopruntime
choco install -y tor-browser
choco install -y python --version=3.10.0
choco install -y 7zip.install
choco install -y qbittorrent
# Note: The following line is commented out since 'microsoft-windows-terminal' is not working through Chocolatey
# choco install -y microsoft-windows-terminal
choco install -y git
choco install -y vcredist140
choco install -y green-tunnel-gui
choco install -y powertoys
choco install -y autoruns
choco install -y musicbee
choco install -y sudo
choco install -y vscode
choco install -y autohotkey

# Install packages using Windows Package Manager (winget)
winget install -e --id Valve.Steam
