@echo off
cd /d "%~dp0"
if exist "%~dp0Start.vbs" (
    start "" wscript.exe "%~dp0Start.vbs"
) else (
    start "" powershell.exe -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File "%~dp0powershell\MediaDownloader.ps1"
)
exit