# CleanPlay v1 Installation Guide

Follow these instructions to install and activate CleanPlay v1 in VLC Media Player.

---

## Easiest Method: One-Click Installer (Recommended)

We provide simple installer scripts that automatically create directories, copy files, and configure VLC settings for you.

### Windows:
1. **Download and Unzip** the CleanPlay folder.
2. Double-click the **`install.bat`** file.
3. The installer will create the folders, copy the scripts, close VLC, and configure the settings.
4. Open VLC Media Player and activate it under **View > CleanPlay v1**.

### macOS:
1. Open your Terminal.
2. Navigate to the `cleanplay-vlc` directory.
3. Run the installer script:
   ```bash
   ./install.sh
   ```
4. Open VLC Media Player and activate it under **View > CleanPlay v1**.

---

## Manual Method

If you prefer to install the files manually, follow these steps:

### Step 1: Copy files to your VLC directories

1. Copy the extension UI script **`cleanplay_v1.lua`** and the **`profanity_lists/`** folder into your VLC **extensions** folder:
   - **Windows Path**: `%APPDATA%\vlc\lua\extensions\`
   - **macOS Path**: `~/Library/Application Support/org.videolan.vlc/lua/extensions/`
   *(Create the `lua` and `extensions` folders if they do not exist).*

2. Copy the background interface script **`cleanplay_intf_v1.lua`** into your VLC **intf** folder:
   - **Windows Path**: `%APPDATA%\vlc\lua\intf\`
   - **macOS Path**: `~/Library/Application Support/org.videolan.vlc/lua/intf/`
   *(Create the `intf` folder if it does not exist).*

#### Expected File Structure on macOS:
```text
~/Library/Application Support/org.videolan.vlc/
└── lua/
    ├── extensions/
    │   ├── cleanplay_v1.lua
    │   └── profanity_lists/
    │       ├── mild.txt
    │       ├── standard.txt
    │       └── strict.txt
    └── intf/
        └── cleanplay_intf_v1.lua
```

### Step 2: Configure VLC to load the background interface

1. Open VLC Media Player.
2. Go to **Tools > Preferences** (or press `Ctrl + P`).
3. In the bottom-left corner of the window, under **Show settings**, click **All**.
4. In the left panel, click on **Interface** to expand it, then select **Main interfaces**.
5. On the right panel, check the **Lua interpreter** box.
6. In the left panel, click on the arrow next to **Main interfaces** to expand it, then click on **Lua**.
7. In the **Lua interface** text box on the right, type:
   `cleanplay_intf_v1`
8. Click **Save** and restart VLC.

---

## How to Use CleanPlay v1

You can watch the [CleanPlay Tutorial Video](https://us06web.zoom.us/clips/share/zWDc3rZyTSOW7ejBc1vYsA) for a complete visual guide on how to use the extension, or follow the steps below:

1. Start playing a video in VLC.
2. Go to **View > CleanPlay v1** in the VLC top menu to open the filter control panel.
3. Load your subtitles:
   - If you have an external `.srt` or `.vtt` file, paste its path into the **Subtitle File** text box and click **Load Subtitle**.
   - If the subtitle file is in the same folder as the video with the same name, or if you are playing an MKV file containing embedded subtitles, click **Autoload from Video Dir**.
4. Click the **Apply Settings** button to sync the profanity timestamp data with the background interface script.
5. You can verify the background script is active by looking at the **Ticks** count under **Real-time Stats**—it will count up continuously!
