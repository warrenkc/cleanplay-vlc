# CleanPlay v1 Installation Guide

Follow these instructions to install and activate CleanPlay v1 in VLC Media Player on Windows.

---

## Easiest Method: One-Click Installer (Recommended)

We provide a simple installer script that automatically creates directories, copies files, and configures VLC settings for you.

1. **Download and Unzip** the CleanPlay folder.
2. Double-click the **`install.bat`** file.
3. The installer will:
   - Create `%APPDATA%\vlc\lua\extensions\` and `%APPDATA%\vlc\lua\intf\` if they do not exist.
   - Copy `cleanplay_v1.lua`, `cleanplay_intf_v1.lua`, and the `profanity_lists/` folder to the correct folders.
   - Safely close VLC if it is running.
   - Update your VLC config (`vlcrc`) to load the silent background interface.
4. Open VLC Media Player.
5. Go to **View > CleanPlay v1** in the VLC top menu to activate it.

---

## Manual Method

If you prefer to install the files manually, follow these steps:

### Step 1: Copy files to your VLC directories

1. Copy the extension UI script **`cleanplay_v1.lua`** and the **`profanity_lists/`** folder into your VLC **extensions** folder:
   - **Path**: `%APPDATA%\vlc\lua\extensions\`
   *(Create the `lua` and `extensions` folders if they do not exist).*

2. Copy the background interface script **`cleanplay_intf_v1.lua`** into your VLC **intf** folder:
   - **Path**: `%APPDATA%\vlc\lua\intf\`
   *(Create the `intf` folder if it does not exist).*

#### Expected File Structure:
```text
%APPDATA%\vlc\
└── lua\
    ├── extensions\
    │   ├── cleanplay_v1.lua
    │   └── profanity_lists\
    │       ├── mild.txt
    │       ├── standard.txt
    │       └── strict.txt
    └── intf\
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

1. Start playing a video in VLC.
2. Go to **View > CleanPlay v1** in the VLC top menu to open the filter control panel.
3. Load your subtitles:
   - If you have an external `.srt` or `.vtt` file, paste its path into the **Subtitle File** text box and click **Load Subtitle**.
   - If the subtitle file is in the same folder as the video with the same name, or if you are playing an MKV file containing embedded subtitles, click **Autoload from Video Dir**.
4. Click the **Apply Settings** button to sync the profanity timestamp data with the background interface script.
5. You can verify the background script is active by looking at the **Ticks** count under **Real-time Stats**—it will count up continuously!
