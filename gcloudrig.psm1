# gCloudRig Powershell module

# Module level variables
# NOTE: these are NOT accessible within a Workflow
[String]$Username = 'gcloudrig'
[String]$InstallLogFile = "c:\gcloudrig\installer.txt"
[String]$InstallCompleteFile = "c:\gcloudrig\installer.complete"

# TODO workflows run in a separate space, you have to pass any variables in
workflow Install-gCloudRig {
  Param (
    [Hashtable] $Options
  )
  #  $Options = @{
  #    "TimeZone" = "Americas/Los_Angeles"
  #    "Set1610VideoModes" = $false
  #    "VideoMode" = "1920x1080"
  #    "ZeroTierNetwork" = $null
  #    "Install" = @{
  #      "Battlenet" = $true
  #      "Steam"     = $true
  #    }
  #  }

  Set-SetupState "installing"
  Write-Status -Sev DEBUG "Beginning of Install-gCloudRig..."
  Write-Status -Sev DEBUG "$Using:Options"

  InlineScript {
    New-GcloudrigDirs
    Install-PackageTools
    Install-DeviceManagementModule

    # install ZT early so user can auth this node while the install runs
    # if $Options['ZeroTierNetwork'] is defined
    Install-ZeroTier (Get-HashValue $Using:Options "ZeroTierNetwork")

    # this requires a reboot
    Disable-WindowsDefenderStage1
  }

  Write-Status "Rebooting(2/6)..."
  Restart-Computer -Force -Wait

  InlineScript {
    # this requires a reboot
    Disable-WindowsDefenderStage2
    Optimize-ForGamingPerformance 
  }
  
  Write-Status "Rebooting(3/6)..."
  Restart-Computer -Force -Wait

  InlineScript {
    # this requires a reqboot
    Install-NvidiaDrivers
    Install-NVFBCEnable
    If(Get-HashValue $Using:Options "Set1610VideoModes" $false) {
      Set-1610VideoModes 
    }
    Set-GcloudrigDisplayResolution (Get-HashValue $Using:Options "VideoMode")
  }

  Write-Status "Rebooting(4/6)..."
  Restart-Computer -Force -Wait

  InlineScript {
    # must be done after nVidia drivers are installed and a reboot
    Set-VirtualDisplayAdapter
  }
  
  Write-Status "Rebooting(5/6)..."
  Restart-Computer -Force -Wait

  InlineScript {
    Install-VirtualSoundCard 

    Disable-AutomaticWindowsUpdate
    Invoke-WindowsUpdate 
  }

  Write-Status "Rebooting(6/6)..."
  Restart-Computer -Force -Wait

  InlineScript {
    Install-TightVNC
    Install-Parsec
    Install-OptionalSoftware (Get-HashValue $Using:Options "Install")

    Optimize-DesktopExperience 
    New-GcloudrigShortcuts
  }

  InlineScript {
    # all is complete, update setup state, remove the startup job
    $(date) | Out-File "c:\gcloudrig\installer.complete"
    Disable-GcloudrigInstaller
    Set-SetupState "complete"
    Write-Status "------ All done! ------"
  }
}

## Functions

Function Get-SpecialFolder {
  Param([parameter(Mandatory=$true)] [String] $Name)

  return [System.Environment]::GetFolderPath($Name)
}

# Get-HashValue(h,k[,d]) -> h[k] if k in h, else d.  d defaults to $null.
Function Get-HashValue {
  Param (
    [parameter(Mandatory=$true)] [Hashtable] $Hashtable,
    [parameter(Mandatory=$true)] [System.Object] $Key,
    [AllowNull()]                [System.Object] $Default
  )
  If($Hashtable.Keys -contains $Key) {
    return $Hashtable[$Key]
  } Else {
    return $Default
  }
}

Function Install-OptionalSoftware {
  Param (
    [parameter(Mandatory=$true)] [Hashtable] $InstallOptions
  )

  If(Get-HashValue $InstallOptions "Battlenet" $false) {
    Install-Battlenet
  }
  If(Get-HashValue $InstallOptions "Steam" $false) {
    Install-Steam 
  }

}

Function New-GcloudrigDirs {
  $baseDir = "C:\gcloudrig"
  $dirs = @('', 'downloads', 'logs')
  ForEach($subdir in $dirs) {
    $dir=(Join-Path $baseDir $subdir)
    If( -Not (Test-Path -Path $dir )) {
      Write-Status -Sev DEBUG ("creating {0}" -f $dir)
      New-Item -Path $dir -ItemType directory | Out-Null
    }
  }
}

Function Disable-WindowsDefenderStage1 {
  Write-Status "Disable Windows Defender, stage 1"
  Set-MpPreference -DisableRealtimeMonitoring $true

  # now reboot, then run Disable-WindowsDefenderStage2
}

Function Disable-WindowsDefenderStage2 {
  Write-Status "Disable Windows Defender, stage 2"
  # TODO check stage 1 has been run
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot" -Name Start -Value 4
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter" -Name Start -Value 4
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv" -Name Start -Value 4
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc" -Name Start -Value 4
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name Start -Value 4
  Disable-ScheduledTask -TaskName 'Windows Defender Cleanup' -TaskPath '\Microsoft\Windows\Windows Defender'
  Disable-ScheduledTask -TaskName 'Windows Defender Scheduled Scan' -TaskPath '\Microsoft\Windows\Windows Defender'
  Disable-ScheduledTask -TaskName 'Windows Defender Verification' -TaskPath '\Microsoft\Windows\Windows Defender'
  Disable-ScheduledTask -TaskName 'Windows Defender Cache Maintenance' -TaskPath '\Microsoft\Windows\Windows Defender'
}

Function Optimize-ForGamingPerformance {
  Write-Status "Disabling things that slow down the system unexpectedly..."

  # turn off ie security
  $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
  $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
  Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
  Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0

  # firewall off (off for now, shouldnt be needed)
  Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

  # priority to programs, not background
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38

  # explorer set to performance
  Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

  # disable crash dump
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -Value 0

  # disable some more scheduled tasks
  Disable-ScheduledTask -TaskName 'ServerManager' -TaskPath '\Microsoft\Windows\Server Manager'
  Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag'
  Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk'
  Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis'
  Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup'
  Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance'
  Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing'

  # disable unnecessary services
  $services = @(
    "diagnosticshub.standardcollector.service" # Microsoft (R) Diagnostics Hub Standard Collector Service
    "DiagTrack"                                # Diagnostics Tracking Service
    "dmwappushservice"                         # WAP Push Message Routing Service
    "lfsvc"                                    # Geolocation Service
    "MapsBroker"                               # Downloaded Maps Manager
    "NetTcpPortSharing"                        # Net.Tcp Port Sharing Service
    "RemoteRegistry"                           # Remote Registry
    "SharedAccess"                             # Internet Connection Sharing (ICS)
    "TrkWks"                                   # Distributed Link Tracking Client
    "WbioSrvc"                                 # Windows Biometric Service
    "XblAuthManager"                           # Xbox Live Auth Manager
    "XblGameSave"                              # Xbox Live Game Save Service
    "LanmanServer"                             # File/Printer sharing
    "Spooler"                                  # Printing stuff
    "RemoteAccess"                             # Routing and Remote Access
  )
  foreach ($service in $services) {
    Set-Service $service -startuptype "disabled"
    Stop-Service $service -force
  }
  Write-Status "  done."
}

Function New-GcloudrigShortcuts {
  Write-Status "Creating gCloudRig desktop shortcuts"
  # create shortcut to disconnect
  New-Shortcut -shortcutPath "$home\Desktop\Disconnect RDP.lnk" -targetPath "C:\Windows\System32\cmd.exe" -arguments @'
/c "for /F "tokens=1 delims=^> " %i in ('""%windir%\system32\qwinsta.exe" | "%windir%\system32\find.exe" /I "^>rdp-tcp#""') do "%windir%\system32\tscon.exe" %i /dest:console"
'@

  # create shortcut to update nVidida drivers
  New-Shortcut -shortcutPath "$home\Desktop\Update nVidia Drivers.lnk" -targetPath "powershell" -arguments '-noexit "&{Import-Module GcloudRig; Install-NvidiaDrivers}"'

  # create shortcut to lock down remote access
  New-Shortcut -shortcutPath "$home\Desktop\Post ZeroTier Setup Security.lnk" -targetPath "powershell" -arguments '-noexit "&{Import-Module GcloudRig; Protect-GcloudrigRemoteAccess}"'
}

Function Install-DeviceManagementModule {
  # for Device Management
  Write-Status "Installing Powershell Device Management module"
  Save-UrlToFile -URL "https://gallery.technet.microsoft.com/Device-Management-7fad2388/file/65051/2/DeviceManagement.zip" -File "c:\gcloudrig\downloads\DeviceManagement.zip"
  Expand-Archive -LiteralPath "c:\gcloudrig\downloads\DeviceManagement.zip" -DestinationPath "c:\gcloudrig\downloads\DeviceManagement"
  Move-Item "c:\gcloudrig\downloads\DeviceManagement\Release" $PSHOME\Modules\DeviceManagement
  (Get-Content "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1").replace("PowerShellHostVersion = '3.0'", "PowerShellHostVersion = ''") | Out-File "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1"
}

Function Install-7Zip {
  Write-Status "Installing 7-zip"
  $downloadPage = Invoke-WebRequest -Uri https://www.7-zip.org/download.html
  $url=("https://www.7-zip.org/{0}" -f ($downloadPage.Links | Where {$_.outerHTML -Like '*x64.exe*Download*'} | Select-Object -First 1 | %{ $_.href }))
  Save-UrlToFile -URL $url -File "c:\gcloudrig\downloads\7zip.exe"
  Start-Process "c:\gcloudrig\downloads\7zip.exe" -ArgumentList '/S /D="C:\gcloudrig\7zip"' -Wait
}

Function Install-PackageTools {
  # TODO replace with Chocolatey

  # 7za needed for extracting some exes
  Install-7Zip
  
  # package manager stuff
  Write-Status "Installing NuGet Package Provider"
  Install-PackageProvider -Name NuGet -Force
}

Function Install-ZeroTier {
  Param (
    [AllowNull()] [String] $Network
  )
  Write-Status "Installing ZeroTier..."

  # disable ipv6 
  # TODO commented out. why does CloudyGamer do this?
  #Set-Net6to4Configuration -State disabled
  #Set-NetTeredoConfiguration -Type disabled
  #Set-NetIsatapConfiguration -State disabled

  # install zerotier
  Save-UrlToFile -URL "https://download.zerotier.com/dist/ZeroTier%20One.msi" -File "c:\gcloudrig\downloads\zerotier.msi"
  & c:\gcloudrig\7zip\7z.exe x -y c:\gcloudrig\downloads\zerotier.msi -oc:\gcloudrig\downloads\zerotier 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
  If(Test-Path "c:\gcloudrig\downloads\zerotier\zttap300.cat") {
    (Get-AuthenticodeSignature -FilePath "c:\gcloudrig\downloads\zerotier\zttap300.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer"
    Import-Certificate -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer" -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'
  }
  & msiexec /qn /i c:\gcloudrig\downloads\zerotier.msi /log c:\gcloudrig\logs\zerotier.msi.log | Out-Null

  $ZTEXE="$Env:ProgramData\ZeroTier\One\zerotier-one_x64.exe"
  If( -Not (Test-Path $ZTEXE)) {
    Write-Status -Sev ERROR "ZeroTier: install failed. check c:\gcloudrig\logs\zerotier.msi.log"
    Return
  }

  # wait for service to start and create identity
  $ZTAuthToken="$Env:ProgramData\ZeroTier\One\authtoken.secret"
  If ( -Not (Test-Path "$ZTAuthToken")) {
    sleep 5
  }

  $ZTStatus = (& $ZTEXE -q /status | ConvertFrom-Json)
  If($ZTStatus) {
    Write-Status "ZeroTier: address $ZTStatus.address"
  }

  # join a network, if specified
  If($Network) {
    & $ZTEXE -ArgumentList "-q /join $Network" | Out-File "c:\gcloudrig\installer.txt" -Append
    Write-Status "ZeroTier: joined network $Network"
  }
}

Function Install-TightVNC {
  Write-Status "Installing TightVNC..."
  $downloadPage=Invoke-WebRequest "https://tightvnc.com/download.php"
  $url=($downloadPage.Links | Where {$_.innerText -like "Installer for Windows*64*bit*"} | Select-Object -First 1 | %{ $_.href})
  Save-UrlToFile -URL $url -File "c:\gcloudrig\downloads\tightvnc.msi"
  $psw = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\").DefaultPassword.substring(0, 8)
  & msiexec /i c:\gcloudrig\downloads\tightvnc.msi /log c:\gcloudrig\logs\tightvnc.msi.log /quiet /norestart ADDLOCAL="Server" SERVER_REGISTER_AS_SERVICE=1 SERVER_ADD_FIREWALL_EXCEPTION=1 SERVER_ALLOW_SAS=1 SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD="$psw" SET_ACCEPTHTTPCONNECTIONS=1 VALUE_OF_ACCEPTHTTPCONNECTIONS=0 2>&1 | Out-Null

  # TODO: install DFMirage driver?
  # $DFMirageUrl=($downloadPage.Links | Where {$_.innerText -Like "Download DFMirage driver"} | %{$_.href})
  # Save-UrlToFile -URL $DFMirageUrl -File "c:\gcloudrig\downloads\dfmirage.exe"
  # & "c:\gcloudrig\downloads\dfmirage.exe" /verysilent /norestart | Out-Null
}    

Function Install-Parsec {
  Write-Status "Installing Parsec..."
  Save-UrlToFile -URL "https://s3.amazonaws.com/parsec-build/package/parsec-windows.exe" -File "c:\gcloudrig\downloads\parsec-windows.exe"
  & c:\gcloudrig\downloads\parsec-windows.exe /S
}

Function Install-NVFBCEnable {
  Write-Status "Install nvfbcenable.exe"
  # TODO find where to get updated version of this
  Save-UrlToFile -URL "https://lg.io/assets/NvFBCEnable.zip" -File "c:\gcloudrig\downloads\NvFBCEnable.zip"
  Expand-Archive -LiteralPath "c:\gcloudrig\downloads\NvFBCEnable.zip" -DestinationPath "c:\gcloudrig\NvFBCEnable"
}

Function Install-Battlenet {
  Write-Status "Installing madalien.com bnetlauncher..."
  # download bnetlauncher 
  $downloadPage = Invoke-Webrequest "https://madalien.com/stuff/bnetlauncher/"
  $url = ($downloadPage.Links | Where {$_.href -Like "https://madalien.com/pub/bnetlauncher/bnetlauncher_*.zip"} | Select-Object -First 1 | %{ $_.href})
  Save-UrlToFile -URL $url -File "c:\gcloudrig\downloads\bnetlauncher.zip"
  Expand-Archive -LiteralPath "c:\gcloudrig\downloads\bnetlauncher.zip" -DestinationPath "c:\gcloudrig\bnetlauncher"

  Write-Status "Installing battle.net..."
  # download bnet (needs to be launched twice because of some error)
  Save-UrlToFile -URL "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP" -File "c:\gcloudrig\downloads\battlenet.exe"
  & c:\gcloudrig\downloads\battlenet.exe --lang=english
  sleep 25
  Stop-Process -Name "battlenet"
  & c:\gcloudrig\downloads\battlenet.exe --lang=english --bnetdir="c:\Program Files (x86)\Battle.net" | Out-Null
}

Function Install-Steam {
  Write-Status "Installing Steam..."
  # download steam
  Save-UrlToFile -URL "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -File "c:\gcloudrig\downloads\steamsetup.exe"
  & c:\gcloudrig\downloads\steamsetup.exe /S | Out-Null

  # create the task to restart steam (such that we're not stuck in services Session 0 desktop when launching)
  $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument @'
-Command "Stop-Process -Name "Steam" -Force -ErrorAction SilentlyContinue ; & 'C:\Program Files (x86)\Steam\Steam.exe'"
'@
  Register-ScheduledTask -Action $action -Description "called by SSM to restart steam. necessary to avoid being stuck in Session 0 desktop." -Force -TaskName "gCloudRig Restart Steam" -TaskPath "\"
}

Function Install-VBAudioCable {
  if ($(Get-Device | where Name -eq "VB-Audio Virtual Cable").count -eq 0) {
    Write-Status "Installing VB-Audio Cable"

    # get link for latest version of VB-Audio Cable
    $downloadPage = Invoke-WebRequest "https://www.vb-audio.com/Cable/"
    $downloadLink=($downloadPage.Links | Where {$_.href -Like '*/Download_CABLE/*'} | Select-Object -First 1 | %{ $_.href })

    # download and install driver
    Save-UrlToFile -URL $downloadLink -File "c:\gcloudrig\downloads\vbcable.zip"
    If (Test-Path "c:\gcloudrig\downloads\vbcable.zip") {
      Expand-Archive -LiteralPath "c:\gcloudrig\downloads\vbcable.zip" -DestinationPath "c:\gcloudrig\downloads\vbcable"
      (Get-AuthenticodeSignature -FilePath "c:\gcloudrig\downloads\vbcable\vbaudio_cable64_win7.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "c:\gcloudrig\downloads\vbcable\vbcable.cer"
      Import-Certificate -FilePath "c:\gcloudrig\downloads\vbcable\vbcable.cer" -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'
      & c:\gcloudrig\downloads\vbcable\VBCABLE_Setup_x64.exe -i

      # AFAIK no silent install, so kill the process after giving it time to finish installing
      Sleep 10
      Get-Process | Where { $_.ProcessName -eq "VBCABLE_Setup_x64" } | Stop-Process

      Import-Module DeviceManagement
      if ($(Get-Device | where Name -eq "VB-Audio Virtual Cable").count -eq 0) {
        Write-Status "VB-Cable failed to install"
      }
    } Else {
      Write-Status -Sev ERROR "VB-Cable driver download failed"
    }
  } Else {
    Write-Status "VB-Cable already installed"
  }
}

Function Install-VirtualSoundCard {
  # auto start audio service
  Set-Service Audiosrv -startuptype "automatic"
  Start-Service Audiosrv

  $audio_device = Get-CimInstance win32_sounddevice | Where-Object {$_.Status -eq "OK"}
  If (-Not $audio_device) {
    Write-Status "Installing virtual sound card..."
    Install-VBAudioCable
    # TODO add support for optionally installing Razer Surround instead
  }
}

Function Disable-AutomaticWindowsUpdate {
  Write-Status "Disabling automatic Windows Update"
  Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
  Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
}

Function Invoke-WindowsUpdate {
  Write-Status "Running Windows Update (this may take a while)..."

  # install windows update automation and run it
  Install-Module PSWindowsUpdate -Force
  Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false
  Get-WUInstall -MicrosoftUpdate -AcceptAll -IgnoreReboot
  Write-Status "Windows Update done."
}

Function Optimize-DesktopExperience {
  Write-Status "Configuring Desktop..."

  # show file extensions, hidden items and disable item checkboxes
  $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  Set-ItemProperty $key HideFileExt 0
  Set-ItemProperty $key HideDrivesWithNoMedia 0
  Set-ItemProperty $key Hidden 1
  Set-ItemProperty $key AutoCheckSelect 0

  # weird accessibility stuff
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506"
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122"
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "58"

  # disable telemetry
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" -Value 0

  # don't combine taskbar buttons and no tray hiding stuff
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarGlomLevel -Value 2
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name EnableAutoTray -Value 0

  # hide the touchbar button on the systray
  Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace" -Name PenWorkspaceButtonDesiredVisibility -Value 0

  # TODO set timezone 
  # Set-TimeZone $Using:TimeZone
}

Function Set-VirtualDisplayAdapter {
  Write-Status "Removing basic display adapter and enabling nvfbc..."

  # disable the basic display adapter and its monitors
  Import-Module DeviceManagement
  Get-Device | where Name -eq "Microsoft Basic Display Adapter" | Disable-Device  # aws/gce
  #Get-Device | where Name -eq "Microsoft Hyper-V Video" | Disable-Device  # azure
  #Get-Device | where Name -eq "Generic PnP Monitor" | where DeviceParent -like "*BasicDisplay*" | Disable-Device  # azure

  # delete the basic display adapter's drivers (since some games still insist on using the basic adapter)
  takeown /f C:\Windows\System32\Drivers\BasicDisplay.sys
  icacls C:\Windows\System32\Drivers\BasicDisplay.sys /grant "$env:username`:F"
  move C:\Windows\System32\Drivers\BasicDisplay.sys C:\Windows\System32\Drivers\BasicDisplay.old

  # enable NvFBC
  & c:\gcloudrig\NvFBCEnable\NvFBCEnable.exe -enable -noreset | Out-Null
}

Function Set-GcloudrigDisplayResolution {
  Param (
    [parameter(Mandatory=$true)] [String] $VideoMode
  )

  If($VideoMode) {
    Try {
      $width,$height = $VideoMode.Split('x')
    } Catch {
      Write-Status -Sev ERROR "couldn't parse requested video mode: `"$VideoMode`".  Use WIDTHxHEIGHT, eg. 1920x1080"
      Return
    }
    Set-DisplayResolution -Width $width -Height $height -Force
  }
}

Function Set-SetupState {
  Param([parameter(Mandatory=$true)] [String] $State)

  & gcloud compute project-info add-metadata --metadata "gcloudrig-setup-state=$State" --quiet 2>&1 | Out-Null
  Write-Status -Sev DEBUG "changed setup state to $State"
}

Function Get-SetupState {
  $SetupStateExists=(Get-GceMetadata -Path "project/attributes" | Select-String "gcloudrig-setup-state")
  if ($SetupStateExists) {
    $SetupState=(Get-GceMetadata -Path "project/attributes/gcloudrig-setup-state")
  } Else {
    $SetupState = $null
  }
  return $SetupState
}

Function Write-Status {
  Param(
    [parameter(Mandatory=$true)] [String] $Text,
    [String] $Sev = "INFO"
  )
  If (Test-Path "c:\gcloudrig") {
    "$(Date) $Sev $Text" | Out-File "c:\gcloudrig\installer.txt" -Append
  }
  New-GcLogEntry -Severity "$Sev" -LogName gcloudrig-install -TextPayload "$Text" | Out-Null
}

Function Save-UrlToFile {
  Param(
    [parameter(Mandatory=$true)] [String] $URL,
    [parameter(Mandatory=$true)] [String] $File
  )

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  (New-Object System.Net.WebClient).DownloadFile($URL, $File)
  if (Test-Path $File) {
    Write-Status -Sev DEBUG "downloaded $URL to $File"
  } else {
    Write-Status -Sev DEBUG "download of $URL failed"
    throw "download of $URL failed"
  }
}

Function New-Shortcut {
  Param(
    [parameter(Mandatory=$true)] [String] $shortcutPath,
    [parameter(Mandatory=$true)] [String] $targetPath,
    [parameter(Mandatory=$true)] [String] $arguments
  )

  $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
  $Shortcut.TargetPath = $targetPath
  $Shortcut.Arguments = $arguments
  $Shortcut.Save()
  $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
  $bytes[0x15] = $bytes[0x15] -bor 0x20
  [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
}

Function Install-NvidiaDrivers {
  Param(
    [String] $downloadDir = "c:\gcloudrig\downloads",
    [String] $nvidiaDriverBucket = "nvidia-drivers-us-public"
  )
  # see https://cloud.google.com/compute/docs/gpus/add-gpus#install-driver-manual

  $currentVersion = Get-Package | Where { $_.Name -like "NVIDIA Graphics Driver*" } | %{ $_.Version }
  If (!$currentVersion) {
    # assume this is a fresh install
    $currentVersion=0
  }

  # Query GCS for the latest nVidia GRID driver
  # download if newer than current install
  Get-GcsObject -Bucket $nvidiaDriverBucket -Prefix "GRID" |
   Where { $_.Name -like "*_grid_win10_server2016_64bit_international.exe" } |
   Sort -property Name |
   Select-Object -Last 1 |
   ForEach-Object { 
     $thisVersion=$_.Name.Split("/")[2].Split("_")[0]
     If ( $thisVersion -gt $currentVersion ) { 
       $nvidiaDir = Join-Path $downloadDir "nvidia-$thisVersion"
       $nvidiaSetup = Join-Path $nvidiaDir "setup.exe"
       $outFile = Join-Path $downloadDir "nvidia-$thisVersion.exe"

       Write-Status "Install-NvidiaDrivers: want to install $thisVersion (upgrade from: $currentVersion)"
       Write-Status -Sev DEBUG ("Install-NvidiaDrivers: download {0}" -f $_.Name)
       Read-GcsObject -InputObject $_ -OutFile $outFile -Force
       # if download succeeded, install
       If (Test-Path $outFile) {
         Write-Status -Sev DEBUG "Install-NvidiaDrivers: extract $outFile"
         & c:\gcloudrig\7zip\7z.exe x -y $outFile -o"$nvidiaDir" 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
         Write-Status -Sev DEBUG "Install-NvidiaDrivers: run $nvidiaSetup"
         & $nvidiaSetup -noreboot -clean -s 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
         Write-Status "Install-NvidiaDrivers: $nvidiaSetup done."
       }
     } Else { 
       Write-Status "Install-NvidiaDrivers: current: $currentVersion >= latest: $thisVersion"
     }
   }
}

Function Set-1610VideoModes {
  # set proper video modes
  # default: {*}S 720x480x8,16,32,64=1; 720x576x8,16,32,64=8032;SHV 1280x720x8,16,32,64 1680x1050x8,16,32,64 1920x1080x8,16,32,64 2048x1536x8,16,32,64=1; 1920x1440x8,16,32,64=1F; 640x480x8,16,32,64 800x600x8,16,32,64 1024x768x8,16,32,64=1FFF; 1920x1200x8,16,32,64=3F; 1600x900x8,16,32,64=3FF; 2560x1440x8,16,32,64 2560x1600x8,16,32,64=7B; 1600x1024x8,16,32,64 1600x1200x8,16,32,64=7F;1280x768x8,16,32,64 1280x800x8,16,32,64 1280x960x8,16,32,64 1280x1024x8,16,32,64 1360x768x8,16,32,64 1366x768x8,16,32,64=7FF; 1152x864x8,16,32,64=FFF;
  (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Video\*\0000") | Where ProviderName -eq "NVIDIA" | ForEach { Set-ItemProperty $_.PSPath -Name "NV_Modes" -Value "{*}S 1024x640 1280x800 1440x900 1680x1050 1920x1200 2304x1440 2560x1600=1;" }
}

Function Update-GcloudRigModule {
 
  $SetupScriptUrlAttribute="gcloudrig-setup-script-gcs-url"
  if (Get-GceMetadata -Path "project/attributes" | Select-String $SetupScriptUrlAttribute) {
    $SetupScriptUrl=(Get-GceMetadata -Path project/attributes/$SetupScriptUrlAttribute)

    & gsutil cp $SetupScriptUrl "$Env:Temp\gcloudrig.psm1" | Out-Null
    if (Test-Path "$Env:Temp\gcloudrig.psm1") {
      New-Item -ItemType directory -Path "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig" -Force | Out-Null
      Copy-Item "$Env:Temp\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force | Out-Null
    }
  }
}

Function Get-ZeroTierIPv4Address {
  $ZTDIR="C:\ProgramData\ZeroTier\One"
  $ZTEXE=(Join-Path $ZTDIR "zerotier-one_x64.exe")
  if (Test-Path "$ZTDIR") {
    # get ZT network address
    $ZTNetwork = & $ZTEXE -q /network | ConvertFrom-Json
    If ($ZTNetwork) {
      # parse for IPv4 address
      Return $ZTNetwork.assignedAddresses | Where{ $_ -like "*/24" } | Select-Object -First 1 | %{ $_.Split("/")[0] }
    } Else {
      Write-Error "Failed to get ZeroTier IPv4 address"
      Return
    }
  } Else {
    Write-Error "ZeroTier One not installed"
    Return
  }
}

Function Protect-TightVNC {
  Param([Parameter(Mandatory=$true)] [String] $ZTIPv4address)
  # Lockdown TightVNC to ZeroTier network only

  $ZTNetworkAddress = $ZTIPv4address.Split(".")[0..2] -Join '.'
  if($ZTNetworkAddress) {
    Stop-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue
    $IpAccessControl = "{0}.1-{0}.254:0,0.0.0.0-255.255.255.255:1" -f $ZTNetworkAddress
    Set-ItemProperty "HKLM:\SOFTWARE\TightVNC\Server" "IpAccessControl" -Value $IpAccessControl
    Start-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue
  }
}

Function Protect-Parsec {
  Param([Parameter(Mandatory=$true)] [String] $ZTIPv4address)
  # Lockdown Parsec to listen on ZeroTier IPv4 address only
  # advanced settings: see https://parsec.tv/config/
  $ParsecConfig = "$Env:AppData\Parsec\config.txt"
  If( -Not (Test-Path "$ParsecConfig")) {
    Write-Error "Protect-Parsec: $ParsecConfig not found"
    Return
  }
  If( Get-Content $ParsecConfig | Where-Object {$_ -Like "network_ip_address=*"}) {
    Write-Host "Protect-Parsec: network_ip_address already configured."
    Return
  }
  # lock down to ZeroTier network
  "network_ip_address=$ZTIPv4address" | Out-File $ParsecConfig -Append -Encoding ascii
}

Function Protect-GcloudrigRemoteAccess {
  $ZTIPv4Address=(Get-ZeroTierIPv4Address)
  If($ZTIPv4Address) {
    Write-Host "ZeroTier IPv4 Address: $ZTIPv4Address"
    Write-Host "Locking down TightVNC.."
    Protect-TightVNC -ZTIPv4Address $ZTIPv4Address
    Write-Host "Locking down Parsec.."
    Protect-Parsec -ZTIPv4Address $ZTIPv4Address
  } Else {
    Write-Error "failed to get ZeroTier IPv4 Address"
  }
}

Function Disable-PasswordComplexity {
  # disable password complexity (so people can choose whatever password they want)
  secedit /export /cfg "c:\secpol.cfg"
  (Get-Content "c:\secpol.cfg").replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File "c:\secpol.cfg"
  secedit /configure /db c:\windows\security\local.sdb /cfg "c:\secpol.cfg" /areas SECURITYPOLICY
  Remove-Item -Force "c:\secpol.cfg" -Confirm:$false
}

Function New-GcloudrigUser {
  Param(
    [Parameter(Mandatory=$true)] [String] $Username
  )

  # get zone and instance name
  # TODO test if errors from Get-GceMetadata escape ()
  $ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
  $InstanceName=(Get-GceMetadata -Path "instance/name")

  # create a new account and password (in Administrators by default)
  $Password=(gcloud compute reset-windows-password "$InstanceName" --user "$Username" --zone "$ZoneName" --format "value(password)")

  # TODO: put this somewhere safer
  Write-Status "user account created/reset; username:$Username; password:'$Password'"

  return $Password
}

Function Set-Autologon {
  Param(
    [Parameter(Mandatory=$true)] [String] $Username,
    [Parameter(Mandatory=$true)] [String] $Password
  )

  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" -Value "1" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUsername" -Value "$Username" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" -Value "$Password" -type String
}

Function Disable-UserAccessControl {
  Write-Status -Sev DEBUG "Disabling UAC"
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -PropertyType DWord -Value 0 -Force
}

Function Invoke-GcloudrigInstaller {
  # This is called from a .lnk in CommonStartup
  # main automated install loop
  
  # Only run for the gcloudrig user
  if ($Env:Username -ne "$Script:Username") {
    Exit
  }

  $SetupState=Get-SetupState
  switch($SetupState) {
    "bootstrap" {
      Write-Status -Sev DEBUG "Starting gCloudRigInstaller job..."
      $SetupOptions = @{}
      If(Get-GceMetadata -Path "project/attributes" | Select-String "gcloudrig-setup-options") {
        $SetupOptions=Get-GceMetadata -Path "project/attributes/gcloudrig-setup-options" | ConvertFrom-Json
      }
      Install-gCloudRig -JobName gCloudRigInstaller -Option $SetupOptions -AsJob
      break
    }
    "installing" {
      $job=Get-Job | Where {$_.Name -eq "gCloudRigInstaller"}
      If( -Not $job) {
        Write-Status -Sev ERROR "gCloudRigInstaller job not found"
        Return
      }

      # store output from Install-gCloudRig job
      if ($job.HasMoreData -eq $true) {
        Receive-Job -Job $job 2>&1 | Out-File "$Script:InstallLogFile" -Append
      }
      switch($job.State) {
        "Suspended" {
          Write-Status -Sev DEBUG "Resuming gCloudRigInstaller job..."
          Resume-Job -Job $job
          }
        "Failed" {
          Write-Status -Sev ERROR "gCloudRigInstaller job FAILED..."
          }
      }
      break
    }
    default {
      Write-Status -Sev DEBUG "Invoke-GcloudrigInstaller called with state: $SetupState"
    }
  }
}

Function Enable-GcloudrigInstaller {
  New-Shortcut -shortcutPath (Join-Path (Get-SpecialFolder "CommonStartUp") "gcloudriginstaller.lnk") -targetPath "powershell" -arguments '-noexit "&{Import-Module gCloudRig; Invoke-GcloudrigInstaller}"'
}

Function Disable-GcloudrigInstaller {
  Remove-Item (Join-Path (Get-SpecialFolder "CommonStartUp") "gcloudriginstaller.lnk") -Force
}

# called from gcloudrig-boot.ps1 every boot
Function Invoke-SoftwareSetupFromBoot {
  Write-Status -Sev DEBUG "Invoke-SoftwareSetupFromBoot"

  # fail fast if install is complete
  If (Test-Path $Script:InstallCompleteFile) {
    Write-Status -Sev DEBUG "$Script:InstallCompleteFile found! all done."
    return
  }

  # if software install has been requested, kick it off
  $SetupState = Get-SetupState
  If ($SetupState -eq "new") {
    Install-Bootstrap
  }
}

Function Install-Bootstrap {
  Write-Status -Sev DEBUG "Install-Bootstrap"

  # create dirs first
  New-GcloudrigDirs

  # set state
  Set-SetupState "bootstrap"
  Write-Status "Bootstrapping gCloudRigInstall"

  # disable password complexity (so people can choose whatever password they want)
  # disabled as GCE creates the password for you
  #Disable-PasswordComplexity

  # create/configure user
  $Password=(New-GcloudrigUser -Username "$Script:Username")

  # set autologon to the gcloudrig user
  #  - required for the installer to run as that user
  #  - convenient for actual usage
  # access is protected by u/p on RDP, Parsec, TightVNC
  Set-Autologon -Username "$Script:Username" -Password "$Password"

  # this will create a shortcut in CommonStartup that will run the installer
  # as the gcloudrig user
  Enable-GcloudrigInstaller

  # disable to allow automated install
  Disable-UserAccessControl

  Write-Status "Created startup .lnk for installer. Rebooting now(1/6)."
  Restart-Computer -Force
}

# vim: set ff=dos
