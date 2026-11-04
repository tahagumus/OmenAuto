# Kur.ps1 - OmenAuto'yu Gorev Zamanlayici'ya kurar (Kur.cmd tarafindan yonetici olarak cagrilir).
# Tetikleyiciler:
#   1) Oturum acilisinda (Baslat > Kapat, guc tusu, yeniden baslatma sonrasi)
#   2) Uykudan / hazirda beklemeden uyanista (kapak acilinca)
# Gorev bir sebeple kapanirsa 1 dakika sonra kendini yeniden baslatir (en fazla 999 kez).

$ErrorActionPreference = 'Stop'
$dir    = $PSScriptRoot
$script = Join-Path $dir 'OmenAuto.ps1'
$user   = "$env:USERDOMAIN\$env:USERNAME"

# Eski surumu durdur
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*\OmenAuto.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OmenAuto.vbs" -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

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
Start-ScheduledTask -TaskName 'OmenAuto'

Get-ScheduledTask -TaskName 'OmenAuto' | Select-Object TaskName, State | Format-Table
Write-Host "Kurulum tamam. OmenAuto acilista ve uykudan uyanista otomatik calisacak."
