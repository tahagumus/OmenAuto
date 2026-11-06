@echo off
rem Oyunda islemci hizlandirmayi KAPATIR ve islemci ayarlarini normale dondurur.
rem Mod, GPU gucu ve fan kontrolu calismaya devam eder.
>"%~dp0CpuBoost.txt" echo 0
call "%~dp0Yeniden-Baslat.cmd"
echo Islemci hizlandirma KAPALI. Islemci ayarlari normal.
timeout /t 3 >nul
