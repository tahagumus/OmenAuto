@echo off
rem Calisan OmenAuto'yu durdurup zamanlanmis gorevi yeniden baslatir.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*OmenAuto.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 2 >nul
powershell -NoProfile -Command "Start-ScheduledTask -TaskName 'OmenAuto'"
echo OmenAuto yeniden baslatildi.
timeout /t 3 >nul
