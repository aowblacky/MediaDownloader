Set WshShell = CreateObject("WScript.Shell")
strRoot = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strRoot & "powershell\MediaDownloader.ps1""", 0, False