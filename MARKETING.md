# CleanPlay: VLC Profanity Filter Promotion & Marketing Guide

Use these pre-written copy-paste templates to promote and market CleanPlay on GitHub, Reddit, and community forums.

---

## 1. GitHub Repository Details

### Repository Short Description (Tagline)
> A privacy-first, fully offline VLC extension that automatically mutes movie profanity using local subtitle timings. Features a silent background service and built-in MKV subtitle extractor.

### Repository Topics / Tags
`vlc-extension` `vlc-media-player` `profanity-filter` `content-filter` `privacy-first` `offline-first` `mkv-parser` `lua-scripting` `parental-control`

---

## 2. Reddit Promotion Template
*Recommended subreddits: `r/vlc`, `r/ParentingTech`, `r/selfhosted`, `r/openSource`*

### Title
> [Open Source] CleanPlay: A local, privacy-first profanity filter extension for VLC Player (with one-click installer)

### Post Body
> Hey everyone,
>
> I wanted to share a project I’ve been working on: **CleanPlay**, a fully offline and privacy-first profanity filter extension for VLC Media Player on Windows.
>
> Unlike browser-based filters or cloud solutions, CleanPlay runs **100% locally** and does not use any internet connections, cloud APIs, or speech-to-text engines. Instead, it utilizes your video’s subtitle track (`.srt` or `.vtt` files) to automatically mute the audio at exact profanity timestamps.
>
> ### Key Features:
> * 🔒 **100% Private & Local**: Subtitles are parsed and processed completely on your own machine.
> * ⚡ **Decoupled Background Service**: Bypasses VLC's extension sandbox limitations by running a silent background thread. Mutes and unmutes instantly with zero audio lag.
> * 🎬 **Zero-Setup MKV Subtitle Extraction**: Includes a custom, pure-Lua Matroska binary parser. When playing an MKV file, it automatically extracts and parses the subtitle track in **under 50 milliseconds** (no FFmpeg or MKVToolNix required!).
> * 🗣️ **Smart Word-Level Muting**: Automatically approximates the exact position of a swear word in a sentence, muting only the word itself rather than the entire subtitle block.
> * 🎛️ **Preset Strictness Levels**: Choose between *Mild*, *Standard*, *Strict*, or define your own *Custom* blocked words list.
> * 🚀 **One-Click Installer**: Double-click `install.bat` and it creates the AppData folders, deploys the scripts, and configures your VLC settings automatically.
>
> ### Why I Built This:
> Most content filters require active subscriptions, send audio logs to cloud servers, or are limited to specific streaming browsers. I wanted a self-contained, open-source tool that works for local media files—ideal for parents who want to watch movies with their kids without worrying about language.
>
> ### Source Code & Installation:
> The codebase is fully open-source and ready to go. You can download the release and view the setup guide here:
> 👉 **[Insert Link to Your GitHub Repository]**
>
> I’d love to hear your feedback, feature requests, or suggestions!
>
> Thanks!

---

## 3. VLC Addons (addons.videolan.org) Description

### Product Name
> CleanPlay: Local Profanity Filter Extension (v1.0.0)

### Product Description
> **CleanPlay** is an offline, privacy-first VLC extension that automatically mutes audio when profanity appears in subtitles.
>
> ### Features:
> * **100% Offline**: Runs entirely on your local machine with zero external network requests.
> * **Precision Muting**: Uses a decoupled background interface script running in its own thread to handle volume adjustments instantly without GUI lag.
> * **Direct MKV Extraction**: Features a built-in Matroska binary parser to extract subtitle tracks from `.mkv` files in milliseconds.
> * **Customizable Settings**: Supports Mild, Standard, and Strict presets, custom word additions, pre/post buffer offsets, and smart word-level muting.
>
> ### Installation Note:
> To run the full background service quietly without popping open console windows, Windows users should use the **One-Click Installer** available in our GitHub repository:
> 👉 **[Insert Link to Your GitHub Repository]**
