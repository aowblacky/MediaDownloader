@echo off
cd /d "%~dp0"
if exist "%~dp0Start-MediaDownloader.vbs" (
    start "" wscript.exe "%~dp0Start-MediaDownloader.vbs"
) else (
    start "" powershell.exe -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File "%~dp0MediaDownloader.ps1"
)
exit