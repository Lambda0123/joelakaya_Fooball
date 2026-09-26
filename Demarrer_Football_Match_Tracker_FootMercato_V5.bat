@echo off
title Football Match Tracker V5 - Foot Mercato
echo ==============================================
echo   FOOTBALL MATCH TRACKER V5
echo   Source : FOOT MERCATO
echo ==============================================
echo.
echo Ne fermez pas cette fenetre.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0serveur_footmercato.ps1"
pause
