# ⚡ Media Downloader (Universal Video & Audio Downloader)

A modern, high-performance Windows desktop application to download and convert single or multiple videos and audio streams into **MP4** (Video) or **MP3** (Audio).  
Powered by `yt-dlp` and `FFmpeg`, supporting **YouTube**, **TikTok**, **Instagram**, **Twitter / X**, **Vimeo**, **SoundCloud**, **Twitch**, and 1,000+ other platforms.

---

## 🚀 Quick Start

Simply double-click **`MediaDownloader.bat`**.

- ⚡ **Zero Console Flash**: Launches directly into the modern dark WPF interface with **100% hidden background console**.
- 🛠️ **Automatic Dependency Setup**: On first launch, the required portable binaries (`yt-dlp.exe` and `ffmpeg.exe`) are automatically fetched into the local `bin/` folder.

---

## ✨ Features

- 📋 **Batch Queue Management**: Add single or multiple links at once (paste individual URLs or multiline batches with a single click).
- 🖼️ **Live Metadata & Thumbnail Previews**: Displays video titles, uploader channels, duration, and cover thumbnails instantly for each item.
- 📊 **Real-time Per-Item Progress**: Dedicated progress bar for every video displaying download percentage, transfer speed (e.g. `5.4 MiB/s`), and ETA.
- 🎵 **High-Quality MP3 Conversion**:
  - Highest audio quality (VBR 0 / ~320 kbps).
  - Automatic cover art and metadata tagging.
- 🎬 **MP4 Video Downloads**:
  - Selectable quality profiles: Best Quality (Original/4K), 1080p Full HD, and 720p HD.
  - Seamless stream remuxing and merging via FFmpeg.
- 📁 **Smart Folder & Settings Memory**:
  - Remembers your chosen download directory and preferred format across app restarts in a local `settings.json`.
- 🔄 **Automatic Startup Update Check**:
  - Automatically checks GitHub for new updates on launch and displays a release popup with changelogs and 1-click self-updating.
  - You can also manually trigger checks anytime via **"⟳ Check for Updates"**.

---

## 🛠️ Project Structure

```text
Media Downloader/
│── MediaDownloader.bat       # Single 1-Click Starter in root folder
│── README.md                 # Documentation
│── version.json              # Version descriptor for GitHub updates
│── .gitignore                # Excludes binary folder (bin/) and local config
│── core/                     # Application source code & scripts
│   ├── MediaDownloader.ps1   # Main GUI application (WPF Dark UI + Runspace engine)
│   ├── Setup-Dependencies.ps1# Bootstrapper for yt-dlp & FFmpeg
│   ├── launcher.vbs          # Silent background launcher
│   └── settings.json         # Local user preferences (remembered paths & formats)
└── bin/                      # Portable tools (auto-downloaded on first start)
    ├── yt-dlp.exe
    ├── ffmpeg.exe
    └── ffprobe.exe
```

---

## ⚙️ System Requirements

- **Windows 10 / 11** or Windows Server (with PowerShell 5.1 or higher)
- Active Internet connection for downloads