-- CleanPlay VLC Interface Script v1
-- Runs in the background to monitor playback time and mute audio when profanity occurs.

vlc.msg.info("CleanPlay Interface v1 Starting...")

local is_currently_muted = false
local saved_volume = 256
local user_was_muted = false

local last_windows_str = nil
local active_mute_windows = {}
local last_time = 0

-- Helper to parse the serialized mute windows from the shared variable
local function parse_mute_windows(str)
    local windows = {}
    if not str or str == "" then return windows end
    for range in string.gmatch(str, "([^;]+)") do
        local start_str, end_str = string.match(range, "([%d%.]+)-([%d%.]+)")
        if start_str and end_str then
            table.insert(windows, {
                start_time = tonumber(start_str),
                end_time = tonumber(end_str)
            })
        end
    end
    return windows
end

-- Helper to set mute state
local function set_mute_state(should_mute)
    if should_mute then
        if vlc.volume and vlc.volume.set then
            pcall(vlc.volume.set, 0)
        end
    else
        if vlc.volume and vlc.volume.set then
            pcall(vlc.volume.set, saved_volume)
        end
    end
end

-- Muting logic matching cleanplay_v1.lua
local function apply_mute(should_mute, current_time)
    local current_vol = 256
    if vlc.volume and vlc.volume.get then
        local ok, val = pcall(vlc.volume.get)
        if ok and val then current_vol = val end
    end
    local currently_muted = (current_vol == 0)
    
    if should_mute then
        if not is_currently_muted then
            user_was_muted = currently_muted
            if current_vol > 0 then
                saved_volume = current_vol
            end
            vlc.msg.info(string.format("CleanPlay Intf: MUTING at %.2fs (saved vol: %d)", current_time or 0, saved_volume))
            set_mute_state(true)
            is_currently_muted = true
        else
            set_mute_state(true)
        end
    else
        if is_currently_muted then
            vlc.msg.info(string.format("CleanPlay Intf: UNMUTING at %.2fs (restoring vol: %d)", current_time or 0, saved_volume))
            if not user_was_muted then
                set_mute_state(false)
            end
            is_currently_muted = false
        else
            if current_vol > 0 and current_vol ~= saved_volume then
                saved_volume = current_vol
            end
        end
    end
end

-- Wait for playlist to be initialized at startup
local pl = nil
for i = 1, 50 do
    pl = vlc.object.playlist()
    if pl then break end
    vlc.misc.mwait(vlc.misc.mdate() + 100000) -- Wait 100ms
end

if not pl then
    vlc.msg.err("CleanPlay Interface v1: Playlist object not found after waiting!")
    return
end

-- Initialize variables on the playlist object if they don't exist
pcall(vlc.var.create, pl, "cleanplay-v1-enabled", "false")
pcall(vlc.var.create, pl, "cleanplay-v1-mute-windows", "")
pcall(vlc.var.create, pl, "cleanplay-v1-muted", "false")
pcall(vlc.var.create, pl, "cleanplay-v1-ticks", 0)

vlc.msg.info("CleanPlay Interface v1 Loop Started.")
local tick_count = 0

while true do
    local ok, err = pcall(function()
        -- Increment local tick and update playlist variable
        tick_count = tick_count + 1
        
        if vlc.var and vlc.var.set then
            pcall(vlc.var.set, pl, "cleanplay-v1-ticks", tick_count)
        end
        
        -- Check if filter is enabled
        local enabled = "false"
        if vlc.var and vlc.var.get then
            enabled = vlc.var.get(pl, "cleanplay-v1-enabled") or "false"
        end
        
        if enabled ~= "true" then
            apply_mute(false, 0)
            if vlc.var and vlc.var.set then
                pcall(vlc.var.set, pl, "cleanplay-v1-muted", "false")
            end
            return
        end
        
        -- Check if active input is present
        local input = vlc.object.input()
        if not input then
            apply_mute(false, 0)
            if vlc.var and vlc.var.set then
                pcall(vlc.var.set, pl, "cleanplay-v1-muted", "false")
            end
            return
        end
        
        -- Get current time in seconds
        local time_micro = vlc.var.get(input, "time")
        if not time_micro or time_micro < 0 then
            apply_mute(false, 0)
            if vlc.var and vlc.var.set then
                pcall(vlc.var.set, pl, "cleanplay-v1-muted", "false")
            end
            return
        end
        local current_time = time_micro / 1000000
        
        -- Detect seek
        local time_diff = current_time - last_time
        if tick_count > 1 and math.abs(time_diff) > 1.5 then
            vlc.msg.info(string.format("CleanPlay Intf: Seek detected! Jumped from %.2fs to %.2fs", last_time, current_time))
        end
        last_time = current_time
        
        -- Get and parse mute windows if they changed
        local windows_str = vlc.var.get(pl, "cleanplay-v1-mute-windows")
        if windows_str ~= last_windows_str then
            last_windows_str = windows_str
            active_mute_windows = parse_mute_windows(windows_str)
            vlc.msg.info("CleanPlay Intf: Loaded " .. tostring(#active_mute_windows) .. " mute windows.")
        end
        
        -- Check if current time is within any mute window
        local should_mute = false
        for _, win in ipairs(active_mute_windows) do
            if current_time < win.start_time then
                break
            end
            if current_time >= win.start_time and current_time <= win.end_time then
                should_mute = true
                break
            end
        end
        
        -- Apply mute status
        apply_mute(should_mute, current_time)
        
        if vlc.var and vlc.var.set then
            if should_mute then
                pcall(vlc.var.set, pl, "cleanplay-v1-muted", "true")
            else
                pcall(vlc.var.set, pl, "cleanplay-v1-muted", "false")
            end
        end
    end)
    
    if not ok then
        vlc.msg.err("CleanPlay Interface v1 Error: " .. tostring(err))
    end
    
    -- Sleep for 100ms
    vlc.misc.mwait(vlc.misc.mdate() + 100000)
end
