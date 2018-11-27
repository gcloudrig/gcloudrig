workflow Install-gCloudRig {
  Param (
    [parameter(Mandatory=$true)] [String] $TimeZone,
    [parameter(Mandatory=$true)] [Boolean] $Set1610VideoModes
  )

  Write-Status "Beginning of gcloudrig workflow..."

  InlineScript {
    Write-Status "Doing initial install, and disabling uac/windefender..."

    # initial init
    New-Item -ItemType directory -Path "c:\gcloudrig\downloads" -Force

    # disable windows defender
    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-Status "  done."
  }

  Write-Status "Rebooting..."
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
  
  Write-Status "Rebooting..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    Write-Status "Creating shortcuts and installing TightVNC and other tooling..."

    # create shortcut to disconnect
    $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$home\Desktop\Disconnect.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\cmd.exe"
    $Shortcut.Arguments = @'
/c "for /F "tokens=1 delims=^> " %i in ('""%windir%\system32\qwinsta.exe" | "%windir%\system32\find.exe" /I "^>rdp-tcp#""') do "%windir%\system32\tscon.exe" %i /dest:console"
'@
    $Shortcut.Save()
    $bytes = [System.IO.File]::ReadAllBytes("$home\Desktop\Disconnect.lnk")
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes("$home\Desktop\Disconnect.lnk", $bytes)

    # 7za needed for extracting some exes
    Download-File -URL "https://lg.io/assets/7za.zip" -File "c:\gcloudrig\downloads\7za.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\7za.zip" -DestinationPath "c:\gcloudrig\7za"

    # package manager stuff
    Install-PackageProvider -Name NuGet -Force

    # for Device Management
    Download-File -URL "https://gallery.technet.microsoft.com/Device-Management-7fad2388/file/65051/2/DeviceManagement.zip" -File "c:\gcloudrig\downloads\DeviceManagement.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\DeviceManagement.zip" -DestinationPath "c:\gcloudrig\downloads\DeviceManagement"
    Move-Item "c:\gcloudrig\downloads\DeviceManagement\Release" $PSHOME\Modules\DeviceManagement
    (Get-Content "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1").replace("PowerShellHostVersion = '3.0'", "PowerShellHostVersion = ''") | Out-File "$PSHOME\Modules\DeviceManagement\DeviceManagement.psd1"
    Import-Module DeviceManagement

    # install tightvnc
    Download-File -URL "http://www.tightvnc.com/download/2.8.5/tightvnc-2.8.5-gpl-setup-64bit.msi" -File "c:\gcloudrig\downloads\tightvnc.msi"
    $psw = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\").DefaultPassword.substring(0, 8)
    & msiexec /i c:\gcloudrig\downloads\tightvnc.msi /quiet /norestart ADDLOCAL="Server" SERVER_REGISTER_AS_SERVICE=1 SERVER_ADD_FIREWALL_EXCEPTION=1 SERVER_ALLOW_SAS=1 SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD=$psw | Out-Null
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

    # nvidia driver
    # from https://cloud.google.com/compute/docs/gpus/add-gpus#install-driver-manual
    # TODO: parse https://storage.googleapis.com/nvidia-drivers-us-public/ for latest driver
    $GCEnVidiaDriver = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/386.09_grid_win10_server2016_64bit_international.exe"
    Download-File -URL $GCEnVidiaDriver -File "c:\gcloudrig\downloads\nvidia.exe"
    & c:\gcloudrig\7za\7za x c:\gcloudrig\downloads\nvidia.exe -oc:\gcloudrig\downloads\nvidia
    & c:\gcloudrig\downloads\nvidia\setup.exe -noreboot -clean -s | Out-Null

    # set proper video modes
    # default: {*}S 720x480x8,16,32,64=1; 720x576x8,16,32,64=8032;SHV 1280x720x8,16,32,64 1680x1050x8,16,32,64 1920x1080x8,16,32,64 2048x1536x8,16,32,64=1; 1920x1440x8,16,32,64=1F; 640x480x8,16,32,64 800x600x8,16,32,64 1024x768x8,16,32,64=1FFF; 1920x1200x8,16,32,64=3F; 1600x900x8,16,32,64=3FF; 2560x1440x8,16,32,64 2560x1600x8,16,32,64=7B; 1600x1024x8,16,32,64 1600x1200x8,16,32,64=7F;1280x768x8,16,32,64 1280x800x8,16,32,64 1280x960x8,16,32,64 1280x1024x8,16,32,64 1360x768x8,16,32,64 1366x768x8,16,32,64=7FF; 1152x864x8,16,32,64=FFF;
    if ($Using:Set1610VideoModes) {
      (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Video\*\0000") | where ProviderName -eq "NVIDIA" | foreach { Set-ItemProperty $_.PSPath -Name "NV_Modes" -Value "{*}S 1024x640 1280x800 1440x900 1680x1050 1920x1200 2304x1440 2560x1600=1;" }
    }
    Write-Status "  done."
  }

  Write-Status "Rebooting..."
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
    Download-File -URL "https://lg.io/assets/NvFBCEnable.zip" -File "c:\gcloudrig\downloads\NvFBCEnable.zip"
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\NvFBCEnable.zip" -DestinationPath "c:\gcloudrig\NvFBCEnable"
    & c:\gcloudrig\NvFBCEnable\NvFBCEnable.exe -enable -noreset
    Write-Status "  done."
  }
  
  Write-Status "Rebooting..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    Write-Status "Installing sound card..."

    # auto start audio service
    Set-Service Audiosrv -startuptype "automatic"
    Start-Service Audiosrv

    # download and install driver
    (New-Object System.Net.WebClient).DownloadFile("http://vbaudio.jcedeveloppement.com/Download_CABLE/VBCABLE_Driver_Pack43.zip", "c:\gcloudrig\downloads\vbcable.zip")
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
    Write-Status "Installing VPN..."

    # disable ipv6 
    # TODO commented out. why does CloudyGamer do this?
    #Set-Net6to4Configuration -State disabled
    #Set-NetTeredoConfiguration -Type disabled
    #Set-NetIsatapConfiguration -State disabled

    # install zerotier
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object System.Net.WebClient).DownloadFile("https://download.zerotier.com/dist/ZeroTier%20One.msi", "c:\gcloudrig\downloads\zerotier.msi")
    & c:\gcloudrig\7za\7za x c:\gcloudrig\downloads\zerotier.msi -oc:\gcloudrig\downloads\zerotier
    (Get-AuthenticodeSignature -FilePath "c:\gcloudrig\downloads\zerotier\zttap300.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer"
    Import-Certificate -FilePath "c:\gcloudrig\downloads\zerotier\zerotier.cer" -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher'
    & msiexec /qn /i c:\gcloudrig\downloads\zerotier.msi | Out-Null

    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Installing Parsec..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object System.Net.WebClient).DownloadFile("https://s3.amazonaws.com/parsec-build/package/parsec-windows.exe", "c:\gcloudrig\downloads\parsec-windows.exe")
    & c:\gcloudrig\downloads\parsec-windows.exe
    Write-Status "  done."
  }

  InlineScript {
    Write-Status "Installing Bnet and Steam..."

    # TODO: add param to make bnet optional
    # download bnetlauncher
    (New-Object System.Net.WebClient).DownloadFile("http://madalien.com/pub/bnetlauncher/bnetlauncher_v18.zip", "c:\gcloudrig\downloads\bnetlauncher.zip")
    Expand-Archive -LiteralPath "c:\gcloudrig\downloads\bnetlauncher.zip" -DestinationPath "c:\gcloudrig\bnetlauncher"

    # download bnet (needs to be launched twice because of some error)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object System.Net.WebClient).DownloadFile("https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP", "c:\gcloudrig\downloads\battlenet.exe")
    & c:\gcloudrig\downloads\battlenet.exe --lang=english
    sleep 25
    Stop-Process -Name "battlenet"
    & c:\gcloudrig\downloads\battlenet.exe --lang=english --bnetdir="c:\Program Files (x86)\Battle.net" | Out-Null

    # TODO: add param to make steam optional
    # download steam
    (New-Object System.Net.WebClient).DownloadFile("https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe", "c:\gcloudrig\downloads\steamsetup.exe")
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

  Write-Status "Rebooting..."
  Restart-Computer -Force -Wait
  Write-Status "  done."

  InlineScript {
    # all is complete, remove the startup job
    Remove-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk" -Force
    Write-Status "------ All done! ------"
  }
}

Function Write-Status {
  Param([parameter(Mandatory=$true)] [String] $Text)
  "$(Date) $Text" | Out-File "c:\gcloudrig\installer.txt" -Append
  gcloud logging write gcloudrig-install "$Text"
}

Function Download-File {
  Param(
    [parameter(Mandatory=$true)] [String] $URL,
    [parameter(Mandatory=$true)] [String] $File
  )

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  (New-Object System.Net.WebClient).DownloadFile($URL, $File)
  if (Test-Path $File) {
    Write-Status "  downloaded $File"
  } else {
    Write-Status "  download of $URL failed"
    throw "download of $URL failed"
  }
}

Function New-gCloudRigInstall {
  Param([parameter(Mandatory=$true)] [String] $Password)

  # create gcloudrig dir for file storage and logging
  New-Item -ItemType directory -Path "c:\gcloudrig" -Force
  Write-Status "Hello! We'll be installing now."

  # disable password complexity (so people can choose whatever password they want)
  secedit /export /cfg "c:\secpol.cfg"
  (Get-Content "c:\secpol.cfg").replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File "c:\secpol.cfg"
  secedit /configure /db c:\windows\security\local.sdb /cfg "c:\secpol.cfg" /areas SECURITYPOLICY
  Remove-Item -Force "c:\secpol.cfg" -Confirm:$false

  # create the gcloudrig user
  $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force
  New-LocalUser "gcloudrig" -Password $SecurePass -PasswordNeverExpires
  Add-LocalGroupMember -Group "Administrators" -Member "gcloudrig"

  # set up autologin
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" -Value "1" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUsername" -Value "gcloudrig" -type String
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" -Value "$Password" -type String

  # disable uac
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -PropertyType DWord -Value 0 -Force

  # write the startup job (to be run only for the gcloudrig user)
$StartupCommands = @'
if ($env:USERNAME -eq "gcloudrig") {
  if (Test-Path "c:\gcloudrig\downloads") {
    gcloud logging write gcloudrig-install "Resuming install job..."
    Get-Job "gCloudRigInstaller" | Where {$_.State -eq "Suspended"} | Resume-Job
  } else {
    # First time
    gcloud logging write gcloudrig-install "Running gCloudRigInstaller..."
    Import-Module gCloudRig
    Install-gCloudRig -JobName gCloudRigInstaller -TimeZone "Pacific Standard Time" -Set1610VideoModes $true -AsJob
  }
}
'@
  $StartupCommands | Out-File "c:\gcloudrig\installer.ps1"

  # run the startup job as an admin
  $ShortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk"
  $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath)
  $Shortcut.TargetPath = "powershell"
  $Shortcut.Arguments = "-noexit -file c:\gcloudrig\installer.ps1"
  $Shortcut.Save()
  $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
  $bytes[0x15] = $bytes[0x15] -bor 0x20
  [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)

  Write-Status "Created gcloudrig user and startup job. Rebooting now."
  Restart-Computer -Force
}

# vim: set ff=dos
