@echo off
cd /d "%~dp0"
if exist "%~dp0core\launcher.vbs" (
    start "" wscript.exe "%~dp0core\launcher.vbs"
) else (
    start "" powershell.exe -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File "%~dp0core\MediaDownloader.ps1"
)
exit