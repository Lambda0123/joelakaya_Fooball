@echo off
title Football Match Tracker V4
echo =========================================
echo   FOOTBALL MATCH TRACKER V4
echo =========================================
echo.
echo IMPORTANT : laissez cette fenetre ouverte.
echo Le navigateur va s'ouvrir automatiquement.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0serveur_v4.ps1"
echo.
pause
