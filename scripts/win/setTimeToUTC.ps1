# script came from: https://devblogs.microsoft.com/scripting/update-or-add-registry-key-value-with-powershell/
# values for script came from: https://weblogs.asp.net/dfindley/Set-hardware-clock-to-UTC-on-Windows-_2800_or-how-to-make-the-clock-work-on-a-Mac-Book-Pro_2900_

# Registry path for where the key should go
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
# name of registry key you are adding
$Name = "RealTimeIsUniversal"
# value of key
$value = "1"

# make sure path exists
IF(!(Test-Path $registryPath))
{
    # create path if it doesn't
    New-Item -Path $registryPath -Force
}

# add registry key and value
Write-Output "Adding utc registry key"
New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force

# make sure windows time service is runnning
Write-Output "Starting windows time service"
net start "Windows Time"

Write-Output "Sleeping for 5 seconds"
Start-Sleep 5

# syncing windows time so it uses new utc time setting read more here: https://weblogs.asp.net/dfindley/Set-hardware-clock-to-UTC-on-Windows-_2800_or-how-to-make-
Write-Output "Syncing time service with new key added"
w32tm /resync

Write-Output "Congrats, you will need to give it a few second, but you should now have the time service running that will adjust your time to the necssary UTC conversion"
Write-Output "So from now on you will only need to do the following to synchronize the service"
Write-Output "w32tm /resync"
Write-Output "execute the command above (i.e. copy and paste it) now, so you can simple search through your windows history to find it later."