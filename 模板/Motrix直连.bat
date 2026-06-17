@echo off
chcp 65001 >nul
title Motrix 直连(不走 Clash)
color 0A
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MotrixProxy\motrix-proxy.ps1" -Mode direct
echo.
pause
