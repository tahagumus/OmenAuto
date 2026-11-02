@echo off
rem OmenAuto kurulumu (OmenMon surumu).
rem Oturum acildiginda OmenAuto.ps1'i yonetici yetkisiyle, gizli olarak calistiran bir zamanlanmis gorev olusturur.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"

echo Eski surum durduruluyor...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*OmenAuto.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
del /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OmenAuto.vbs" 2>nul

echo Zamanlanmis gorev olusturuluyor...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"' + '%DIR%' + '\OmenAuto.ps1\"');" ^
  "$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME;" ^
  "$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest;" ^
  "$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew;" ^
  "Register-ScheduledTask -TaskName 'OmenAuto' -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null;" ^
  "Start-ScheduledTask -TaskName 'OmenAuto';" ^
  "Get-ScheduledTask -TaskName 'OmenAuto' | Select-Object TaskName, State | Format-Table"

echo.
echo Kurulum tamam. Her oturum acilisinda OmenAuto otomatik calisacak.
pause
