@echo off
chcp 65001 >nul
title Motrix 走 Clash 7890
color 0E
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MotrixProxy\motrix-proxy.ps1" -Mode proxy
echo.
pause
