@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\scribus-win-prod.ps1" %*
exit /b %ERRORLEVEL%
