@echo off
rem Sensor testi (sadece okuma). Oyun acikken de calistirilabilir.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Durum.ps1"
echo.
echo Sonuc Durum.txt dosyasina yazildi. Bu pencereyi kapatabilirsin.
timeout /t 5 >nul
