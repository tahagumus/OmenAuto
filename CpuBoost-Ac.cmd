@echo off
rem Oyunda islemci hizlandirmayi ACAR (varsayilan olarak kapalidir).
>"%~dp0CpuBoost.txt" echo 1
call "%~dp0Yeniden-Baslat.cmd"
echo Islemci hizlandirma ACIK. Oyun acilinca devreye girer.
timeout /t 3 >nul
