# ==============================================================================
# Setup-Dependencies.ps1 - Media Downloader Tool Bootstrapper
# Schneller & zuverlässiger Download von yt-dlp.exe und ffmpeg.exe
# ==============================================================================

param(
    [string]$BinDir = "$PSScriptRoot\bin",
    [switch]$ForceUpdate
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

if (-not (Test-Path -Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

$ytDlpPath  = Join-Path $BinDir "yt-dlp.exe"
$ffmpegPath = Join-Path $BinDir "ffmpeg.exe"
$ffprobePath = Join-Path $BinDir "ffprobe.exe"

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Download-Fast {
    param([string]$Url, [string]$Destination)
    
    # Prüfe ob curl.exe vorhanden ist (extrem schnell)
    $curl = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curl) {
        Write-LogMessage "Lade mit curl: $Url"
        & $curl.Source -L "$Url" -o "$Destination" --retry 3 --silent --show-error
        if ((Test-Path $Destination) -and (Get-Item $Destination).Length -gt 1000000) {
            return $true
        }
    }

    # Fallback: WebClient
    Write-LogMessage "Lade mit .NET WebClient: $Url"
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $webClient.DownloadFile($Url, $Destination)
    $webClient.Dispose()
    return (Test-Path $Destination)
}

# 1. yt-dlp.exe
if ($ForceUpdate -or -not (Test-Path $ytDlpPath)) {
    Write-LogMessage "Lade neueste yt-dlp.exe herunter..."
    $ytDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
    try {
        Download-Fast -Url $ytDlpUrl -Destination $ytDlpPath
        Write-LogMessage "yt-dlp.exe erfolgreich bereitgestellt." "OK"
    } catch {
        Write-LogMessage "Fehler beim Herunterladen von yt-dlp: $_" "ERROR"
    }
} else {
    Write-LogMessage "yt-dlp.exe ist bereits vorhanden." "OK"
}

# 2. ffmpeg.exe & ffprobe.exe
if (-not (Test-Path $ffmpegPath) -or -not (Test-Path $ffprobePath)) {
    Write-LogMessage "Lade FFmpeg herunter..."
    $ffmpegZipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    $tempZip = Join-Path $env:TEMP "ffmpeg-temp.zip"
    $tempExtract = Join-Path $env:TEMP "ffmpeg-extract-$(Get-Random)"

    try {
        Download-Fast -Url $ffmpegZipUrl -Destination $tempZip
        Write-LogMessage "Entpacke FFmpeg Archive..."
        
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $foundFfmpeg = Get-ChildItem -Path $tempExtract -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
        $foundFfprobe = Get-ChildItem -Path $tempExtract -Recurse -Filter "ffprobe.exe" | Select-Object -First 1

        if ($foundFfmpeg) {
            Copy-Item -Path $foundFfmpeg.FullName -Destination $ffmpegPath -Force
            Write-LogMessage "ffmpeg.exe kopiert." "OK"
        }
        if ($foundFfprobe) {
            Copy-Item -Path $foundFfprobe.FullName -Destination $ffprobePath -Force
            Write-LogMessage "ffprobe.exe kopiert." "OK"
        }

        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

        Write-LogMessage "FFmpeg erfolgreich bereitgestellt." "OK"
    } catch {
        Write-LogMessage "Fehler beim Bereitstellen von FFmpeg: $_" "ERROR"
    }
} else {
    Write-LogMessage "FFmpeg ist bereits vorhanden." "OK"
}

Write-LogMessage "Setup der Tools abgeschlossen." "DONE"