workflow Install-gCloudRig {
  Param (
    [parameter(Mandatory=$true)] [String] $TimeZone,
    [parameter(Mandatory=$true)] [Boolean] $Set1610VideoModes
  )

  Set-SetupState "installing"

  Write-Status "Beginning of gcloudrig workflow..."

  InlineScript {
    Write-Status "Doing initial install, and disabling uac/windefender..."

    # create dir for downloads
    New-Item -ItemType directory -Path "c:\gcloudrig\downloads" -Force

    # disable windows defender
    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-Status "  done."
  }

  Write-Status "Rebooting(2/6)..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    Write-Status "Disabling other things that slow down the system unexpectedly..."

    # finish disabling windows defender
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot" -Name Start -Value 4
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter" -Name Start -Value 4
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv" -Name Start -Value 4
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc" -Name Start -Value 4
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name Start -Value 4
    Disable-ScheduledTask -TaskName 'Windows Defender Cleanup' -TaskPath '\Microsoft\Windows\Windows Defender'
    Disable-ScheduledTask -TaskName 'Windows Defender Scheduled Scan' -TaskPath '\Microsoft\Windows\Windows Defender'
    Disable-ScheduledTask -TaskName 'Windows Defender Verification' -TaskPath '\Microsoft\Windows\Windows Defender'
    Disable-ScheduledTask -TaskName 'Windows Defender Cache Maintenance' -TaskPath '\Microsoft\Windows\Windows Defender'

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
  
  Write-Status "Rebooting(3/6)..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    Write-Status "Creating shortcuts and install other tooling..."
    # this needs to be done before any software installs

    # create shortcut to disconnect
    New-Shortcut -shortcutPath "$home\Desktop\Disconnect RDP.lnk" -targetPath "C:\Windows\System32\cmd.exe" -arguments @'
/c "for /F "tokens=1 delims=^> " %i in ('""%windir%\system32\qwinsta.exe" | "%windir%\system32\find.exe" /I "^>rdp-tcp#""') do "%windir%\system32\tscon.exe" %i /dest:console"
'@

    # create shortcut to update nVidida drivers
    New-Shortcut -shortcutPath "$home\Desktop\Update nVidia Drivers.lnk" -targetPath "powershell" -arguments "-noexit 'import-module gCloudRig; Install-NvidiaDrivers'"

    # 7za needed for extracting some exes
    Write-Status "...installing 7za"
    Save-UrlToFile -URL "https://lg.io/assets/7za.zip" -File "c:\gcloudrig\downloads\7za.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\7za.zip" -DestinationPath "c:\gcloudrig\7za"

    # package manager stuff
    Write-Status "...NuGet Package Provider"
    Install-PackageProvider -Name NuGet -Force

    # for Device Management
    Write-Status "...Powershell Device Management module"
    Save-UrlToFile -URL "https://gallery.technet.microsoft.com/Device-Management-7fad2388/file/65051/2/DeviceManagement.zip" -File "c:\gcloudrig\downloads\DeviceManagement.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\DeviceManagement.zip" -DestinationPath "c:\gcloudrig\downloads\DeviceManagement"
    Move-Item "c:\gcloudrig\downloads\DeviceManagement\Release" $PSHOME\Modules\DeviceManagement
    (Get-Content "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1").replace("PowerShellHostVersion = '3.0'", "PowerShellHostVersion = ''") | Out-File "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1"
    Import-Module DeviceManagement

    Write-Status "done."
  }

  InlineScript {
    Write-Status "Installing VPN..."

    # disable ipv6 
    # TODO commented out. why does CloudyGamer do this?
    #Set-Net6to4Configuration -State disabled
    #Set-NetTeredoConfiguration -Type disabled
    #Set-NetIsatapConfiguration -State disabled

    # install zerotier
    Save-UrlToFile -URL "https://download.zerotier.com/dist/ZeroTier%20One.msi" -File "c:\gcloudrig\downloads\zerotier.msi"
    & c:\gcloudrig\7za\7za x c:\gcloudrig\downloads\zerotier.msi -oc:\gcloudrig\downloads\zerotier
    (Get-AuthenticodeSignature -FilePath "c:\gcloudrig\downloads\zerotier\zttap300.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer"
    Import-Certificate -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer" -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'
    & msiexec /qn /i c:\gcloudrig\downloads\zerotier.msi | Out-Null

    # install tightvnc
    Write-Status "Installing TightVNC..."
    Save-UrlToFile -URL "http://www.tightvnc.com/download/2.8.5/tightvnc-2.8.5-gpl-setup-64bit.msi" -File "c:\gcloudrig\downloads\tightvnc.msi"
    $psw = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\").DefaultPassword.substring(0, 8)
    & msiexec /i c:\gcloudrig\downloads\tightvnc.msi /log c:\gcloudrig\tightvnc.msi.log /quiet /norestart ADDLOCAL="Server" SERVER_REGISTER_AS_SERVICE=1 SERVER_ADD_FIREWALL_EXCEPTION=1 SERVER_ALLOW_SAS=1 SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD="$psw" SET_ACCEPTHTTPCONNECTIONS=1 VALUE_OF_ACCEPTHTTPCONNECTIONS=0 2>&1 | Out-Null
    
    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Setting up nice-to-have settings..."

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

    # dont combine taskbar buttons and no tray hiding stuff
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarGlomLevel -Value 2
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name EnableAutoTray -Value 0

    # hide the touchbar button on the systray
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace" -Name PenWorkspaceButtonDesiredVisibility -Value 0

    # set timezone (disabled for now)
    # Set-TimeZone $Using:TimeZone

    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Installing video card drivers..."
    Install-NvidiaDrivers

    # set proper video modes
    # default: {*}S 720x480x8,16,32,64=1; 720x576x8,16,32,64=8032;SHV 1280x720x8,16,32,64 1680x1050x8,16,32,64 1920x1080x8,16,32,64 2048x1536x8,16,32,64=1; 1920x1440x8,16,32,64=1F; 640x480x8,16,32,64 800x600x8,16,32,64 1024x768x8,16,32,64=1FFF; 1920x1200x8,16,32,64=3F; 1600x900x8,16,32,64=3FF; 2560x1440x8,16,32,64 2560x1600x8,16,32,64=7B; 1600x1024x8,16,32,64 1600x1200x8,16,32,64=7F;1280x768x8,16,32,64 1280x800x8,16,32,64 1280x960x8,16,32,64 1280x1024x8,16,32,64 1360x768x8,16,32,64 1366x768x8,16,32,64=7FF; 1152x864x8,16,32,64=FFF;
    if ($Using:Set1610VideoModes) {
      (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Video\*\0000") | where ProviderName -eq "NVIDIA" | foreach { Set-ItemProperty $_.PSPath -Name "NV_Modes" -Value "{*}S 1024x640 1280x800 1440x900 1680x1050 1920x1200 2304x1440 2560x1600=1;" }
    }
    Write-Status "  done."
  }

  Write-Status "Rebooting(4/6)..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
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

    # install nvfbcenable
    Save-UrlToFile -URL "https://lg.io/assets/NvFBCEnable.zip" -File "c:\gcloudrig\downloads\NvFBCEnable.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\NvFBCEnable.zip" -DestinationPath "c:\gcloudrig\NvFBCEnable"
    & c:\gcloudrig\NvFBCEnable\NvFBCEnable.exe -enable -noreset
    Write-Status "  done."
  }
  
  Write-Status "Rebooting(5/6)..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    Write-Status "Installing sound card..."

    # auto start audio service
    Set-Service Audiosrv -startuptype "automatic"
    Start-Service Audiosrv

    # download and install driver
    Save-UrlToFile -URL "http://vbaudio.jcedeveloppement.com/Download_CABLE/VBCABLE_Driver_Pack43.zip" -File "c:\gcloudrig\downloads\vbcable.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\vbcable.zip" -DestinationPath "c:\gcloudrig\downloads\vbcable"
    (Get-AuthenticodeSignature -FilePath "c:\gcloudrig\downloads\vbcable\vbaudio_cable64_win7.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "c:\gcloudrig\downloads\vbcable\vbcable.cer"
    Import-Certificate -FilePath "c:\gcloudrig\downloads\vbcable\vbcable.cer" -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'
    & c:\gcloudrig\downloads\vbcable\VBCABLE_Setup_x64.exe -i
    Sleep 10
    Stop-Process -Name "VBCable_Setup_x64"
    Import-Module DeviceManagement
    if ($(Get-Device | where Name -eq "VB-Audio Virtual Cable").count -eq 0) {
      throw "VBCable failed to install"
    }
    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Installing Parsec..."
    Save-UrlToFile -URL "https://s3.amazonaws.com/parsec-build/package/parsec-windows.exe" -File "c:\gcloudrig\downloads\parsec-windows.exe"
    & c:\gcloudrig\downloads\parsec-windows.exe

    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Installing Bnet and Steam..."

    # TODO: add param to make bnet optional
    # download bnetlauncher
    Save-UrlToFile -URL "http://madalien.com/pub/bnetlauncher/bnetlauncher_v18.zip" -File "c:\gcloudrig\downloads\bnetlauncher.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\bnetlauncher.zip" -DestinationPath "c:\gcloudrig\bnetlauncher"

    # download bnet (needs to be launched twice because of some error)
    Save-UrlToFile -URL "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP" -File "c:\gcloudrig\downloads\battlenet.exe"
    & c:\gcloudrig\downloads\battlenet.exe --lang=english
    sleep 25
    Stop-Process -Name "battlenet"
    & c:\gcloudrig\downloads\battlenet.exe --lang=english --bnetdir="c:\Program Files (x86)\Battle.net" | Out-Null

    # TODO: add param to make steam optional
    # download steam
    Save-UrlToFile -URL "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -File "c:\gcloudrig\downloads\steamsetup.exe"
    & c:\gcloudrig\downloads\steamsetup.exe /S | Out-Null

    # create the task to restart steam (such that we're not stuck in services Session 0 desktop when launching)
    $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument @'
-Command "Stop-Process -Name "Steam" -Force -ErrorAction SilentlyContinue ; & 'C:\Program Files (x86)\Steam\Steam.exe'"
'@
    Register-ScheduledTask -Action $action -Description "called by SSM to restart steam. necessary to avoid being stuck in Session 0 desktop." -Force -TaskName "gCloudRig Restart Steam" -TaskPath "\"
    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Running windows update and disabling it (this may take a while)..."

    # disable Windows Update
    Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2

    # install windows update automation and run it
    Install-Module PSWindowsUpdate -Force
    Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false
    Get-WUInstall -MicrosoftUpdate -AcceptAll -IgnoreReboot
    Write-Status "  done."
  }

  Write-Status "Rebooting(6/6)..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    # create hardening script
    $HardeningScript = "c:\gcloudrig\hardening.ps1"
    $HardeningCommands = @'
Import-Module gCloudRig;
$ZTIPv4Address = Get-ZeroTierIPv4Address;
If($ZTIPv4Address) {
  Write-Host "ZeroTier IPv4 Address: $ZTIPv4Address";
  Write-Host "Locking down TightVNC.."
  Protect-TightVNC -ZTIPv4Address $ZTIPv4Address;
  Write-Host "Locking down Parsec.."
  Protect-Parsec -ZTIPv4Address $ZTIPv4Address;
} Else {
  Write-Error "failed to get ZeroTier IPv4 Address";
}
'@
    $HardeningCommands | Out-File $HardeningScript

    New-Shortcut -shortcutPath "$home\Desktop\Post ZeroTier Setup Security.lnk" -targetPath "powershell" -arguments "-noexit -file $HardeningScript"
  }

  InlineScript {
    # all is complete, update setup state, remove the startup job
    $(date) | Out-File "C:\gcloudrig\installer.complete"
    Set-SetupState "complete"
    Remove-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk" -Force
    Write-Status "------ All done! ------"
  }
}

Function Set-SetupState {
  Param([parameter(Mandatory=$true)] [String] $State)

  & gcloud compute project-info add-metadata --metadata "gcloudrig-setup-state=$State" --quiet
  Write-Status -Sev DEBUG ("changed setup state to $State")
}

Function Write-Status {
  Param(
    [parameter(Mandatory=$true)] [String] $Text,
    [String] $Sev = "INFO"
  )
  "$(Date) $Sev $Text" | Out-File "c:\gcloudrig\installer.txt" -Append
  New-GcLogEntry -Severity "$Sev" -LogName gcloudrig-install -TextPayload "$Text"
}

Function Save-UrlToFile {
  Param(
    [parameter(Mandatory=$true)] [String] $URL,
    [parameter(Mandatory=$true)] [String] $File
  )

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  (New-Object System.Net.WebClient).DownloadFile($URL, $File)
  if (Test-Path $File) {
    Write-Status -Sev DEBUG "  downloaded $URL to $File"
  } else {
    Write-Status -Sev DEBUG "  download of $URL failed"
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
       Write-Status "Install-NvidiaDrivers: download {0}" -f $_.Name
       Read-GcsObject -InputObject $_ -OutFile $outFile -Force
       # if download succeeded, install
       If (Test-Path $outFile) {
         Write-Status "Install-NvidiaDrivers: extract $outFile"
         & c:\gcloudrig\7za\7za x -y $outFile -o"$nvidiaDir" 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
         Write-Status "Install-NvidiaDrivers: run $nvidiaSetup"
         & $nvidiaSetup -noreboot -clean -s 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
         Write-Status "Install-NvidiaDrivers: $nvidiaSetup done."
       }
     } Else { 
       Write-Status "Install-NvidiaDrivers: current: $currentVersion >= latest: $thisVersion"
     }
   }
}

Function Update-GcloudRigModule {
 
  $SetupScriptUrlAttribute="gcloudrig-setup-script-gcs-url"
  if (Get-GceMetadata -Path "project/attributes" | Select-String $SetupScriptUrlAttribute) {
    $SetupScriptUrl=(Get-GceMetadata -Path project/attributes/$SetupScriptUrlAttribute)

    & gsutil cp $SetupScriptUrl "$Home\Desktop\gcloudrig.psm1"
    if (Test-Path "$Home\Desktop\gcloudrig.psm1") {
      Copy-Item "$Home\Desktop\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force
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
      Return $ZTNetwork.assignedAddresses | Where{ $_ -like "*/24" }
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
  Stop-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue
  $IpAccessControl = "{0}.1-{0}.254:0,0.0.0.0-255.255.255.255:1" -f $ZTNetworkAddress
  Set-ItemProperty "HKLM:\SOFTWARE\TightVNC\Server" "IpAccessControl" -Value $IpAccessControl
  Start-Service -Name 'TightVNC Server' -ErrorAction SilentlyContinue
}

Function Protect-Parsec {
  Param([Parameter(Mandatory=$true)] [String] $ZTIPv4address)
  # Lockdown Parsec to listen on ZeroTier IPv4 address only
  # advanced settings: see https://parsec.tv/config/
  $ParsecConfig = "$Env:AppData\Parsec\config.txt"
  If (Test-Path "$ParsecConfig") {
    # lock down to ZeroTier network
    "network_ip_address=$ZTIPv4address" | Out-File $ParsecConfig -Append
  } Else {
    Write-Error "$ParsecConfig not found"
  }
}

Function Install-Bootstrap {

  # create gcloudrig dir for file storage and logging
  New-Item -ItemType directory -Path "c:\gcloudrig" -Force

  # set state
  Set-SetupState "bootstrap"
  Write-Status "Bootstrapping gCloudRigInstall"

  # disable password complexity (so people can choose whatever password they want)
  secedit /export /cfg "c:\secpol.cfg"
  (Get-Content "c:\secpol.cfg").replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File "c:\secpol.cfg"
  secedit /configure /db c:\windows\security\local.sdb /cfg "c:\secpol.cfg" /areas SECURITYPOLICY
  Remove-Item -Force "c:\secpol.cfg" -Confirm:$false

  # create a new account and password (in Administrators by default)
  $ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
  $InstanceName=(Get-GceMetadata -Path "instance/name")
  $Password=gcloud compute reset-windows-password "$InstanceName" --user "gcloudrig" --zone "$ZoneName" --format "value(password)"

  # TODO: put this somewhere safer
  Write-Status "user account created/reset; username:gcloudrig; password:'$Password'"

  # set up autologin
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" -Value "1" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUsername" -Value "gcloudrig" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" -Value "$Password" -type String

  # disable uac
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -PropertyType DWord -Value 0 -Force

  # write the startup job (to be run only for the gcloudrig user)
  # TODO refactor this to just import-module gcloudrig and call a function
  $StartupCommands = @'
if ($env:USERNAME -eq "gcloudrig") {
  $SetupStateExists=(Get-GceMetadata -Path "project/attributes" | Select-String "gcloudrig-setup-state")
  if ($SetupStateExists) {
    $SetupState=(Get-GceMetadata -Path "project/attributes/gcloudrig-setup-state")
  } else {
    $SetupState="metadata not found"
  }
  
  switch($SetupState) {
    "bootstrap" {
      New-GcLogEntry -LogName gcloudrig-install -Severity DEBUG -TextPayload "installer.ps1:Running gCloudRigInstaller..."
      Import-Module gCloudRig
      Install-gCloudRig -JobName gCloudRigInstaller -TimeZone "Pacific Standard Time" -Set1610VideoModes $true -AsJob
      break
      }
    "installing" {
      New-GcLogEntry -LogName gcloudrig-install -Severity DEBUG -TextPayload "installer.ps1:Resuming gCloudRigInstaller job..."
      Get-Job "gCloudRigInstaller" | Where {$_.State -eq "Suspended"} | Resume-Job
      $job=Get-Job "gCloudRigInstaller"
      if ($job.HasMoreData -eq $true) {
        # store output from Install-gCloudRig job
        Receive-Job -Job $job 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
      }
      switch($job.State) {
        "Suspended" {
          Resume-Job -Job $job
          }
        "Failed" {
          New-GcLogEntry -LogName gcloudrig-install -Severity DEBUG -TextPayload "installer.ps1:gCloudRigInstaller job FAILED..."
          }
      }
      break
      }
    "complete" {
      $job=Get-Job "gCloudRigInstaller"
      if ($job.HasMoreData -eq $true) {
        # store output from Install-gCloudRig job
        Receive-Job -Job $job 2>&1 | Out-File "c:\gcloudrig\installer.txt" -Append
      }
      # TODO put an "exit" here
      break
      }
    default {
      New-GcLogEntry -LogName gcloudrig-install -Severity DEBUG -TextPayload "installer.ps1 called with state: $SetupState"
      }
  }
}
'@
  $StartupCommands | Out-File "c:\gcloudrig\installer.ps1"

  # run the startup job as an admin
  New-Shortcut -shortcutPath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk" -targetPath "powershell" -arguments "-noexit -file c:\gcloudrig\installer.ps1"

  Write-Status "Created gcloudrig user and startup job. Rebooting now(1/6)."
  Restart-Computer -Force
}

# vim: set ff=dos
