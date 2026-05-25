# CleanPlay v1: VLC Profanity Filter Extension

<p align="center">
  <img src="assets/logo.png" alt="CleanPlay Logo" width="200" />
</p>

CleanPlay is a lightweight, fully offline VLC Media Player extension that automatically mutes audio whenever profanity appears in the subtitles. 

Unlike speech-to-text filters, CleanPlay uses local subtitle timestamps as a guide, making it highly accurate, extremely lightweight, and 100% private.

---

## Features

1. **Local & Private**: No internet access, speech-to-text, or external APIs are used. Everything runs locally on your computer.
2. **Decoupled Background Muting**: Uses a persistent background Interface script running in its own thread to poll playback position and perform muting, bypassing the `vlc.timer` sandbox limitation in VLC 3.0+ extensions.
3. **Flexible Subtitle Parsing**: Natively parses standard `.srt` and `.vtt` (WebVTT) subtitle files.
4. **Smart Word-Level Muting**: Offers approximate word-level muting (calculating timing offsets based on the profane word's position in a sentence) so that only the exact word is muted instead of the entire line.
5. **Autoloading**: Automatically searches the directory of the playing video for subtitles with matching filenames or extracts them from the media container.
6. **Robust Pattern Matching**: Detects masked variations of swear words (e.g. `f***`, `f--k`, `sh!t`, `a$$`) automatically using advanced character normalization and wildcard pattern mapping.
7. **Preset Strictness Levels**: Choose between *Mild*, *Standard*, *Strict*, and *Custom* filter presets.
8. **Editable Custom Word List**: Easily add or remove words from a persistent custom blocked list.
9. **Mute Window Merging**: Automatically merges overlapping or closely spaced mute windows to avoid audio flutter.
10. **Fail-Safe Volume Control**: Saves and restores your exact original volume level. Safely handles manual volume changes during muting and guarantees audio is restored if the extension is deactivated.

---

## How It Works

CleanPlay uses a two-part decoupled architecture:
1. **Extension UI (`cleanplay_v1.lua`)**: Opens the control panel from the **View** menu. It parses your subtitles, filters them based on your strictness settings, and serializes the mute timestamps to a global variable registered on VLC's shared playlist object.
2. **Background Interface Script (`cleanplay_intf_v1.lua`)**: Runs silently in the background when VLC starts. It continuously monitors the playback time, checks if it falls inside any mute window, and toggles VLC volume between `0` and your manual listening volume.

---

## Supported Formats

- **SRT (.srt)**: SubRip Subtitle Format.
- **WebVTT (.vtt)**: Web Video Text Tracks Format.

---

## Subtitles in MKV / Embedded Tracks

> [!NOTE]
> **Zero Setup Subtitle Extraction**
> CleanPlay includes a custom, built-in **pure-Lua Matroska and EBML parser** that automatically extracts embedded subtitle tracks (SRT or ASS formats) directly from `.mkv` files.
>
> When you play an MKV video, CleanPlay will scan the container's binary tree, locate the active subtitle track, extract its blocks, and automatically write it out as a `.srt` file next to the video in **under 50 milliseconds**.
>
> You do **not** need to install any external tools or perform any manual steps!

### Backup Extraction Fallbacks (Optional)
If you are using other container formats (like MP4) or the pure-Lua extractor fails due to non-standard encoding, CleanPlay will automatically fall back to executing background command-line tools if they are installed on your path:
* **FFmpeg**: `ffmpeg -y -i input.mp4 -map 0:s:0 subtitles.srt`
* **MKVToolNix**: `mkvextract tracks input.mkv 2:subtitles.srt`

---

## Installation

We provide a **One-Click Installer** for Windows users. Please see [INSTALL.md](INSTALL.md) for step-by-step instructions.
