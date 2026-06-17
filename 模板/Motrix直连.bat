@echo off
title Motrix 直连(不走代理)
color 0A
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MotrixProxy\motrix-proxy.ps1" -Mode direct
echo.
pause