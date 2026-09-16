# ⚡ Media Downloader (Universal Video & Audio Downloader)

Ein modernes, leichtgewichtiges Windows-Tool zum gleichzeitigen Herunterladen und Konvertieren mehrerer Videos in **MP4** (Video) oder **MP3** (Audio).
Unterstützt **YouTube**, **TikTok**, **Instagram**, **Twitter / X**, **Vimeo**, **Soundcloud**, **Twitch** und über 1.000 weitere Plattformen dank `yt-dlp` und `FFmpeg`.

---

## 🚀 Schnellstart

Einfach die Datei **`Start-MediaDownloader.vbs`** (oder `Start-MediaDownloader.bat`) per **Doppelklick** ausführen.
- Es öffnet sich direkt die grafische Oberfläche – **garantiert ohne störendes schwarzes Konsolenfenster** im Hintergrund.
- Beim ersten Start lädt das Programm automatisch die benötigten Tools (`yt-dlp.exe` und `ffmpeg.exe`) in den lokalen `bin/`-Ordner herunter.

---

## ✨ Features

- 📋 **Batch-Warteschlange**: Beliebig viele Video-Links einfügen (einzeln oder per Multiline-Paste).
- 🖼️ **Live-Vorschau**: Zeigt für jedes Video sofort das Vorschaubild (Thumbnail), den Videotitel und die Dauer an.
- 📊 **Echtzeit-Fortschritt**: Individuelle Fortschrittsbalken pro Video mit Live-Geschwindigkeit (z. B. `4.2 MiB/s`) und verbleibender Zeit (ETA).
- 🎵 **MP3 Audio-Konvertierung**:
  - Höchste Audioqualität (VBR 0 / ~320 kbps).
  - Automatisches Einbetten von Titel, Interpret und Cover-Art (Thumbnail).
- 🎬 **MP4 Video-Konvertierung**:
  - Wählbare Auflösungen: Beste Qualität (4K/Original), 1080p Full HD oder 720p HD.
  - Automatisches Zusammenführen von separaten Audio-/Videospuren via FFmpeg.
- 🔄 **GitHub & Tools Auto-Update**: 
  - Mit dem Button *"🔄 Updates prüfen"* wird geprüft, ob eine neue Version von `Media Downloader` auf GitHub vorliegt oder neuere `yt-dlp`/`ffmpeg`-Versionen verfügbar sind.
  - Updates können mit einem Klick automatisch geladen und installiert werden.
- 📁 **Zielordner & Einstellungen merken**: 
  - Standardmäßig unter `Downloads\MediaDownloader`, mit praktischem "Öffnen"-Button.
  - Wenn du einen anderen Ordner oder ein anderes Format wählst, wird dies automatisch in `settings.json` gespeichert und bleibt bei jedem Neustart erhalten.

---

## 🛠️ Dateistruktur

```text
Media Downloader/
│── Start-MediaDownloader.vbs  # Empfohlener 1-Klick Starter (100% ohne Konsolenfenster)
│── Start-MediaDownloader.bat  # Alternativer Windows Batch Starter
│── MediaDownloader.ps1        # Hauptprogramm (WPF Dark UI & Multi-Threading Engine)
│── Setup-Dependencies.ps1     # Bootstrapper für yt-dlp & FFmpeg
│── version.json               # Versionsdatei für GitHub Auto-Updates
│── .gitignore                 # Schließt große Binärdateien (bin/) von Git aus
│── bin/                       # Lokale Tools (wird bei Bedarf automatisch geladen)
│   ├── yt-dlp.exe
│   ├── ffmpeg.exe
│   └── ffprobe.exe
└── README.md                  # Dokumentation
```

---

## ⚙️ Systemvoraussetzungen

- **Windows 10 / 11** oder Windows Server (mit PowerShell 5.1 oder neuer)
- Aktive Internetverbindung für Downloads