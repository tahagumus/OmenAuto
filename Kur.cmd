@echo off
rem OmenAuto kurulumu: yonetici izni ister, sonra Kur.ps1'i calistirir.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Kur.ps1"
echo.
pause
