@echo off
title Football Match Tracker V3
echo.
echo Demarrage de Football Match Tracker V3...
echo Ne fermez PAS cette fenetre pendant l'utilisation.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0serveur_v3.ps1"
pause
