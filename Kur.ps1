# Kur.ps1 - OmenAuto'yu Gorev Zamanlayici'ya kurar (Kur.cmd tarafindan yonetici olarak cagrilir).
# Tetikleyiciler:
#   1) Oturum acilisinda (Baslat > Kapat, guc tusu, yeniden baslatma sonrasi)
#   2) Uykudan / hazirda beklemeden uyanista (kapak acilinca)
# Gorev bir sebeple kapanirsa 1 dakika sonra kendini yeniden baslatir (en fazla 999 kez).
#
# Pencere gizleme: Windows 11'de varsayilan terminal "Windows Terminal" oldugunda
# -WindowStyle Hidden ise yaramaz ve gorev cubugunda PowerShell penceresi kalir.
# Bu yuzden PowerShell, pencere acmayan "conhost.exe --headless" ile baslatilir.
#
# Ayrica OmenTray (saatin yanindaki durum simgesi) ikinci bir gorev olarak kurulur.
# Simge sadece gunlugu okudugu icin yonetici yetkisi OLMADAN calisir.

$ErrorActionPreference = 'Stop'
$dir        = $PSScriptRoot
$script     = Join-Path $dir 'OmenAuto.ps1'
$trayScript = Join-Path $dir 'OmenTray.ps1'
$user       = "$env:USERDOMAIN\$env:USERNAME"

# Eski surumleri durdur (OmenAuto + simge)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { ($_.CommandLine -like '*\OmenAuto.ps1*' -or $_.CommandLine -like '*\OmenTray.ps1*') -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OmenAuto.vbs" -ErrorAction SilentlyContinue

# ---- 1) OmenAuto (yonetici, gizli) ----
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$logon = New-ScheduledTaskTrigger -AtLogOn -User $user

$cls  = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace 'Root/Microsoft/Windows/TaskScheduler'
$wake = New-CimInstance -CimClass $cls -ClientOnly
$wake.Enabled = $true
$wake.Subscription = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''Microsoft-Windows-Power-Troubleshooter''] and EventID=1]]</Select></Query></QueryList>'

$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable

Register-ScheduledTask -TaskName 'OmenAuto' -Action $action -Trigger @($logon, $wake) `
    -Principal $principal -Settings $settings -Force | Out-Null

# ---- 2) OmenTray simgesi (normal kullanici, gizli) ----
$trayAction = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$trayScript`""
$trayPrincipal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$traySettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable

Register-ScheduledTask -TaskName 'OmenAutoTray' -Action $trayAction -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $user) `
    -Principal $trayPrincipal -Settings $traySettings -Force | Out-Null

Start-ScheduledTask -TaskName 'OmenAuto'
Start-ScheduledTask -TaskName 'OmenAutoTray'

Get-ScheduledTask -TaskName 'OmenAuto', 'OmenAutoTray' | Select-Object TaskName, State | Format-Table
Write-Host "Kurulum tamam. OmenAuto acilista ve uykudan uyanista gizli calisacak."
Write-Host "Durum simgesi saatin yaninda: mavi = Quiet, kirmizi = Performance, gri = calismiyor."
