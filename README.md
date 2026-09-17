# Media Downloader (Universal Video & Audio Downloader)

A modern, high-performance Windows desktop application to download and convert single or multiple videos and audio streams into **MP4** (Video) or **MP3** (Audio).  
Powered by `yt-dlp` and `FFmpeg`, supporting **YouTube**, **TikTok**, **Instagram**, **Twitter / X**, **Vimeo**, **SoundCloud**, **Twitch**, and 1,000+ other platforms.

---

## 🚀 Quick Start

Simply double-click **`MediaDownloader.bat`**.

- 🛠️ **Automatic Dependency Setup**: On first launch, the required portable binaries (`yt-dlp.exe` and `ffmpeg.exe`) are automatically fetched into the local `bin/` folder.

---

## ✨ Features

- 📋 **Batch Queue Management**: Add single or multiple links at once (paste individual URLs or multiline batches with a single click).
- 📋 **Auto-Clipboard Monitor**: Automatically detects and enqueues video/audio links copied from your browser.
- 🖼️ **Live Metadata & Thumbnail Previews**: Displays video titles, uploader channels, duration, and cover thumbnails instantly for each item.
- ✏️ **Title & ID3-Tag Editor**: Customize video titles, artist tags, and channel metadata before downloading.
- ✂️ **Inline Video & Audio Trimming**: Define exact start and end timestamps (`00:01:30` - `00:03:45`) to download only specific segments.
- 🛡️ **SponsorBlock Integration**: Automatically skip sponsor segments, intros, outros, and self-promotions on YouTube.
- ⚡ **Download Speed Limiter**: Limit bandwidth consumption (`50M`, `20M`, `10M`, `5M`, `2M`, `1M`, or `Unlimited`).
- 📊 **Real-time Per-Item Progress**: Dedicated progress bar for every video displaying download percentage, transfer speed (e.g. `5.4 MiB/s`), and ETA.
- 🎵 **High-Quality MP3 & Lossless Audio**:
  - Highest audio quality (VBR 0 / ~320 kbps), Apple AAC (M4A), WAV & FLAC lossless formats.
  - Automatic cover art embedding and metadata tagging.
- 🎬 **MP4 Video Downloads**:
  - Selectable quality profiles: Best Quality (Original/4K/8K), 1080p Full HD, and 720p HD.
  - Subtitle embedding and seamless stream merging via FFmpeg.
- ▶️ **Quick Actions & Context Menu**: 1-click **Play** or **Show in Folder** right from the completed queue card or context menu.
- 🔔 **Windows Toast & Tray Notifications**: Non-intrusive balloon notification when entire batch finishes, with direct folder opening on click.
- 📁 **Smart Settings Memory**:
  - Automatically preserves download path, format, speed limits, and option toggles across app restarts.
- 🔄 **Automatic Startup Update Check**:
  - Automatically checks GitHub for new updates on launch and displays an interactive release popup with changelogs and 1-click full ZIP auto-updating.

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
