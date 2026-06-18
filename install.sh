#!/bin/zsh
# CleanPlay v1 macOS Installer
# Installs the VLC CleanPlay extension and background interface.

echo "==================================================="
echo "  Installing CleanPlay v1 for VLC Media Player (macOS)"
echo "==================================================="
echo

# 1. Close VLC if running to prevent configuration overwrite
if pgrep -x "VLC" >/dev/null; then
    echo "Closing running VLC Player to update configuration..."
    killall "VLC" 2>/dev/null
    sleep 2
fi

# 2. Define target paths
EXT_DIR="$HOME/Library/Application Support/org.videolan.vlc/lua/extensions"
INTF_DIR="$HOME/Library/Application Support/org.videolan.vlc/lua/intf"
VLCRC="$HOME/Library/Preferences/org.videolan.vlc/vlcrc"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create directories if they don't exist
echo "Step 1: Creating VLC user directories..."
mkdir -p "$EXT_DIR"
mkdir -p "$INTF_DIR"

# 3. Clean up misplaced files in extensions directory
echo "Step 2: Cleaning up existing folders..."
MISPLACED=(
    "cleanplay_intf_v1.lua"
    "INSTALL.md"
    "README.md"
    "TESTING.md"
    "install.bat"
    "update_vlc_config.ps1"
)
for item in "${MISPLACED[@]}"; do
    if [ -f "$EXT_DIR/$item" ]; then
        rm "$EXT_DIR/$item"
        echo "  -> Removed misplaced file: $item"
    fi
done

# 4. Copy scripts and profanity lists
echo "Step 3: Copying script files..."
if [ -f "$SCRIPT_DIR/cleanplay_v1.lua" ]; then
    cp "$SCRIPT_DIR/cleanplay_v1.lua" "$EXT_DIR/cleanplay_v1.lua"
    echo "  -> Copied cleanplay_v1.lua to extensions folder."
else
    echo "Error: cleanplay_v1.lua not found in current directory!" >&2
    exit 1
fi

if [ -f "$SCRIPT_DIR/cleanplay_intf_v1.lua" ]; then
    cp "$SCRIPT_DIR/cleanplay_intf_v1.lua" "$INTF_DIR/cleanplay_intf_v1.lua"
    echo "  -> Copied cleanplay_intf_v1.lua to intf folder."
else
    echo "Error: cleanplay_intf_v1.lua not found in current directory!" >&2
    exit 1
fi

if [ -d "$SCRIPT_DIR/profanity_lists" ]; then
    rm -rf "$EXT_DIR/profanity_lists"
    cp -R "$SCRIPT_DIR/profanity_lists" "$EXT_DIR/profanity_lists"
    echo "  -> Copied profanity word lists."
else
    echo "Warning: profanity_lists directory not found!" >&2
fi

# 5. Update VLC Configuration
echo "Step 4: Updating VLC configuration (vlcrc)..."
if [ -f "$VLCRC" ]; then
    # Enable extraintf=luaintf
    if grep -q "^#extraintf=" "$VLCRC"; then
        perl -i -pe 's/^#extraintf=.*/extraintf=luaintf/' "$VLCRC"
    elif grep -q "^extraintf=" "$VLCRC"; then
        perl -i -pe 's/^extraintf=.*/extraintf=luaintf/' "$VLCRC"
    else
        echo "extraintf=luaintf" >> "$VLCRC"
    fi

    # Enable lua-intf=cleanplay_intf_v1
    if grep -q "^#lua-intf=dummy" "$VLCRC"; then
        perl -i -pe 's/^#lua-intf=dummy/lua-intf=cleanplay_intf_v1/' "$VLCRC"
    elif grep -q "^#lua-intf=" "$VLCRC"; then
        perl -i -pe 's/^#lua-intf=.*/lua-intf=cleanplay_intf_v1/' "$VLCRC"
    elif grep -q "^lua-intf=" "$VLCRC"; then
        perl -i -pe 's/^lua-intf=.*/lua-intf=cleanplay_intf_v1/' "$VLCRC"
    else
        echo "lua-intf=cleanplay_intf_v1" >> "$VLCRC"
    fi
    echo "  -> VLC configuration updated successfully!"
else
    echo "Warning: Could not locate vlcrc configuration file." >&2
    echo "Make sure you have run VLC at least once." >&2
fi

echo
echo "==================================================="
echo "  CleanPlay v1 Installation Completed Successfully!"
echo "==================================================="
echo "You can now open VLC Player."
echo "Start any video, click View -> CleanPlay v1, and enjoy!"
echo
