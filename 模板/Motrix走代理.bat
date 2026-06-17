@echo off
title Motrix ×ß´úÀí
color 0E
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MotrixProxy\motrix-proxy.ps1" -Mode proxy
echo.
pause