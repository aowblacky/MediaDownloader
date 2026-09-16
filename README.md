# ⚡ Media Downloader (Universal Video & Audio Downloader)

A modern, high-performance Windows desktop application to download and convert single or multiple videos and audio streams into **MP4** (Video) or **MP3** (Audio).  
Powered by `yt-dlp` and `FFmpeg`, supporting **YouTube**, **TikTok**, **Instagram**, **Twitter / X**, **Vimeo**, **SoundCloud**, **Twitch**, and 1,000+ other platforms.

---

## 🚀 Quick Start

Simply double-click **`Start-MediaDownloader.vbs`** (or `Start-MediaDownloader.bat`).

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
- 🔄 **Integrated GitHub Auto-Update**:
  - Click **"⟳ Check for Updates"** to automatically check for newer app releases on GitHub and update `yt-dlp` / `ffmpeg` in the background.

---

## 🛠️ Project Structure

```text
Media Downloader/
│── Start-MediaDownloader.vbs  # Recommended 1-click launcher (pure GUI, 0 console window)
│── Start-MediaDownloader.bat  # Alternative Windows batch launcher
│── MediaDownloader.ps1        # Main application (WPF Dark UI + Runspace engine)
│── Setup-Dependencies.ps1     # Bootstrapper for yt-dlp & FFmpeg
│── version.json               # Version descriptor for GitHub updates
│── settings.json              # Local persistent user preferences (ignored by git)
│── .gitignore                 # Excludes binary folder (bin/) and local config
│── bin/                       # Portable tools (auto-downloaded on first start)
│   ├── yt-dlp.exe
│   ├── ffmpeg.exe
│   └── ffprobe.exe
└── README.md                  # Documentation
```

---

## ⚙️ System Requirements

- **Windows 10 / 11** or Windows Server (with PowerShell 5.1 or higher)
- Active Internet connection for downloads