@echo off
rem OmenAuto'yu ve durum simgesini durdurur, zamanlanmis gorevleri siler (dosyalara dokunmaz).
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -Command "Unregister-ScheduledTask -TaskName 'OmenAuto' -Confirm:$false -ErrorAction SilentlyContinue"
powershell -NoProfile -Command "Unregister-ScheduledTask -TaskName 'OmenAutoTray' -Confirm:$false -ErrorAction SilentlyContinue"
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*OmenAuto.ps1*' -or $_.CommandLine -like '*OmenTray.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
del /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OmenAuto.vbs" 2>nul
echo OmenAuto kaldirildi.
pause
