@echo off
rem Oyun acikken FPS olcer (PresentMon gerekir, README'ye bak). Ayarlari degistirmez.
rem Calistir, hemen oyuna don; 20 sn sonra 15 sn olcer, sonuc FpsOlc-<tarih>.txt dosyasina yazilir.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "%~dp0FpsOlc.ps1"
