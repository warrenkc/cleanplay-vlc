-- CleanPlay VLC Extension
-- Automatically mutes VLC audio when profanity appears in subtitles.
-- Drive mute windows based on subtitle timing, locally and without speech-to-text.

-- Global state variables
local d = nil -- Dialog object
local enable_checkbox = nil
local word_level_checkbox = nil
local file_input = nil
local strictness_dropdown = nil
local pre_buffer_input = nil
local post_buffer_input = nil
local offset_input = nil
local add_word_input = nil
local custom_words_label = nil
local status_label = nil
local mute_status_label = nil
local profanity_count_label = nil
local preview_list = nil
local message_label = nil

local monitor_timer = nil
local current_input = nil
local is_currently_muted = false
local saved_volume = 256 -- 256 is 100% in VLC Lua volume API

local loaded_subtitles = {}
local mute_windows = {}
local detected_count = 0
local custom_words = {}
local active_profanity_set = {}

-- URL decoder helper (decodes %20, etc.)
local function url_decode(str)
    if not str then return "" end
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

-- Converts file:// URIs to local filesystem paths
local function uri_to_path(uri)
    local path = url_decode(uri)
    if string.sub(path, 1, 8) == "file:///" then
        -- Check if it is Windows (has a drive letter after the 3 slashes)
        if string.match(path, "^file:///[A-Za-z]:") then
            path = string.sub(path, 9) -- Remove "file:///"
        else
            path = string.sub(path, 8) -- Remove "file://" but keep the third "/"
        end
    elseif string.sub(path, 1, 7) == "file://" then
        path = string.sub(path, 8)
    end
    path = string.gsub(path, "\\", "/")
    return path
end

-- Trackers for media path and SPU track changes
local current_loaded_media_path = nil
local current_loaded_spu_id = nil
local debug_ticks = 0

-- State trackers to detect UI changes dynamically
local last_strictness_val = 3
local last_pre_buffer = 0.3
local last_post_buffer = 0.2
local last_offset = 0.0
local last_word_level = false

-- Default word list definitions (fallbacks)
local default_mild = {
    "hell", "damn", "crap", "butt", "piss", "darn", "heck", "buttface", "pissed", "pisses", "pissing", "crapper"
}

local default_standard = {
    "ass", "bitch", "bastard", "shit", "pussy", "dick", "cock", "jerk", "asshole", "douche", "craphead", "shitty",
    "bitches", "bitching", "bastards", "shits", "shitted", "shitting", "bullshit", "horseshit", "cocks", "dicks", "assholes",
    "arse", "arsehole"
}

local default_strict = {
    "fuck", "cunt", "motherfuck", "goddamn", "wanker", "slut", "whore", "faggot", "nigger", "retard", "fucking", "fucker",
    "cocksucker", "prick", "twat", "bollocks", "fucks", "fucked", "fuckers", "motherfucker", "motherfuckers", "motherfucking",
    "cunts", "goddamned", "sluts", "whores", "wankers", "pricks", "twats"
}

-- -----------------------------------------------------------------------------
-- VLC Extension Descriptor
-- -----------------------------------------------------------------------------
function descriptor()
    return {
        title = "CleanPlay v1",
        version = "1.0",
        author = "Antigravity",
        url = "https://github.com/cleanplay-vlc",
        shortdesc = "CleanPlay v1 Profanity Filter",
        description = "Mutes audio when profanity appears in subtitles. All processing is local.",
        capabilities = { "input-listener", "playing-listener" }
    }
end

-- -----------------------------------------------------------------------------
-- Lifecycle Methods
-- -----------------------------------------------------------------------------
function activate()
    load_custom_words()
    create_dialog()
    
    -- Initialize variables on the playlist object
    local pl = vlc.object.playlist()
    if pl then
        pcall(vlc.var.create, pl, "cleanplay-v1-enabled", "false")
        pcall(vlc.var.create, pl, "cleanplay-v1-mute-windows", "")
        pcall(vlc.var.create, pl, "cleanplay-v1-muted", "false")
        pcall(vlc.var.create, pl, "cleanplay-v1-ticks", 0)
        
        -- Sync active checkbox setting
        local is_enabled = "false"
        if enable_checkbox and enable_checkbox:get_checked() then
            is_enabled = "true"
        end
        pcall(vlc.var.set, pl, "cleanplay-v1-enabled", is_enabled)
    end
    
    update_ui()
end

function deactivate()
    -- Disable filter on playlist to let interface script unmute immediately
    local pl = vlc.object.playlist()
    if pl then
        pcall(vlc.var.set, pl, "cleanplay-v1-enabled", "false")
    end
    
    -- Cleanup UI
    if d then
        d:delete()
        d = nil
    end
end

function close()
    deactivate()
end

-- -----------------------------------------------------------------------------
-- Playback & Input Event Handlers
-- -----------------------------------------------------------------------------
function input_changed()
    check_track_changes()
    autoload_subtitle(true)
end

function playing_changed()
    check_track_changes()
    update_ui()
end

-- -----------------------------------------------------------------------------
-- UI Dialog Creation and Helpers
-- -----------------------------------------------------------------------------
function create_dialog()
    if d then return end
    d = vlc.dialog("CleanPlay v1 Profanity Filter")
    
    -- Row 1: Header
    d:add_label("<b>CleanPlay Profanity Filter</b>", 1, 1, 4, 1)
    
    -- Row 2: Config Toggles
    enable_checkbox = d:add_check_box("Enable Filter", true, 1, 2, 2, 1)
    word_level_checkbox = d:add_check_box("Approx. Word-Level Mute", false, 3, 2, 2, 1)
    
    -- Row 3: Subtitle file path
    d:add_label("Subtitle File (.srt/.vtt):", 1, 3, 1, 1)
    file_input = d:add_text_input("", 2, 3, 2, 1)
    d:add_button("Load Subtitle", load_subtitle_clicked, 4, 3, 1, 1)
    
    -- Row 4: Action & Timing Adjustments
    d:add_button("Autoload from Video Dir", autoload_clicked, 1, 4, 2, 1)
    d:add_label("Timing Offset (s):", 3, 4, 1, 1)
    offset_input = d:add_text_input("0.0", 4, 4, 1, 1)
    
    -- Row 5: Strictness & Buffer Adjustments
    d:add_label("Strictness:", 1, 5, 1, 1)
    strictness_dropdown = d:add_dropdown(2, 5, 1, 1)
    strictness_dropdown:add_value("Strict (+fuck, cunt...)", 3)
    strictness_dropdown:add_value("Standard (+shit, ass...)", 2)
    strictness_dropdown:add_value("Mild (hell, damn...)", 1)
    strictness_dropdown:add_value("Custom (Custom list only)", 4)
    
    d:add_label("Pre-buffer (sec):", 3, 5, 1, 1)
    pre_buffer_input = d:add_text_input("0.3", 4, 5, 1, 1)
    
    -- Row 6: Post Buffer and Apply Settings
    d:add_button("Apply Settings", apply_settings_clicked, 1, 6, 2, 1)
    d:add_label("Post-buffer (sec):", 3, 6, 1, 1)
    post_buffer_input = d:add_text_input("0.2", 4, 6, 1, 1)
    
    -- Row 7: Custom Word Panel
    d:add_label("Custom Word:", 1, 7, 1, 1)
    add_word_input = d:add_text_input("", 2, 7, 1, 1)
    d:add_button("Add Word", add_word_clicked, 3, 7, 1, 1)
    d:add_button("Remove Word", remove_word_clicked, 4, 7, 1, 1)
    
    -- Row 8: Custom Words display
    custom_words_label = d:add_label("Custom Words: None", 1, 8, 4, 1)
    update_custom_words_display()
    
    -- Row 9: Status / Feedback message
    message_label = d:add_label("<span style='color:green;'>System Ready</span>", 1, 9, 4, 1)
    
    -- Row 10: Section Headers
    d:add_label("<b>Real-time Stats</b>", 1, 10, 2, 1)
    d:add_label("<b>Upcoming Mute Events</b>", 3, 10, 2, 1)
    
    -- Row 11-13: Stats & Preview List side-by-side
    status_label = d:add_label("Status: Active", 1, 11, 2, 1)
    mute_status_label = d:add_label("Mute Status: Not muted", 1, 12, 2, 1)
    profanity_count_label = d:add_label("Profanities Detected: 0", 1, 13, 2, 1)
    
    preview_list = d:add_list(3, 11, 2, 3)
    
    -- Row 14: Refresh Status
    d:add_button("Refresh Status", refresh_status_clicked, 1, 14, 4, 1)
    
    d:show()
end

function update_ui()
    if not d then return end
    
    local pl = vlc.object.playlist()
    local is_enabled = false
    if enable_checkbox then
        is_enabled = enable_checkbox:get_checked()
    end
    
    local filter_status = is_enabled and "Active" or "Disabled"
    
    local time_str = "0.0s"
    local input = vlc.object.input()
    if input then
        local time_micro = vlc.var.get(input, "time")
        if time_micro and time_micro >= 0 then
            time_str = string.format("%.1fs", time_micro / 1000000)
        end
    end
    
    local ticks = 0
    local is_muted = false
    if pl then
        ticks = vlc.var.get(pl, "cleanplay-v1-ticks") or 0
        local muted_str = vlc.var.get(pl, "cleanplay-v1-muted")
        is_muted = (muted_str == "true")
    end
    
    status_label:set_text("Status: " .. filter_status .. " | " .. time_str .. " | Ticks: " .. tostring(ticks))
    profanity_count_label:set_text("Profanities Detected: " .. tostring(detected_count) .. " | Windows: " .. tostring(#mute_windows))
    
    local mute_str = "Not muted"
    if is_muted then
        mute_str = "<span style='color:red;'>MUTED</span>"
    end
    mute_status_label:set_text("Mute Status: " .. mute_str)
    
    d:update()
end

function set_message(text)
    if message_label then
        message_label:set_text(text)
        d:update()
    end
end

-- -----------------------------------------------------------------------------
-- Custom Word List Storage (Local I/O)
-- -----------------------------------------------------------------------------
function get_custom_words_path()
    local dir = ""
    if vlc.config and vlc.config.userdatadir then
        local ok, res = pcall(vlc.config.userdatadir)
        if ok then dir = res end
    end
    if not dir or dir == "" then
        return "cleanplay_custom.txt"
    end
    dir = string.gsub(dir, "[\\/]+$", "") -- Remove trailing slash
    return dir .. "/cleanplay_custom.txt"
end

function load_custom_words()
    custom_words = {}
    local path = get_custom_words_path()
    local f = io.open(path, "r")
    if not f then return end
    for line in f:lines() do
        local word = string.gsub(line, "^%s*(.-)%s*$", "%1")
        word = string.lower(word)
        if word ~= "" then
            custom_words[word] = true
        end
    end
    f:close()
end

function save_custom_words()
    local path = get_custom_words_path()
    local f = io.open(path, "w")
    if not f then return end
    for word, _ in pairs(custom_words) do
        f:write(word .. "\n")
    end
    f:close()
end

function update_custom_words_display()
    if not custom_words_label then return end
    local list = {}
    for w, _ in pairs(custom_words) do
        table.insert(list, w)
    end
    table.sort(list)
    if #list == 0 then
        custom_words_label:set_text("Custom Words: None")
    else
        custom_words_label:set_text("Custom Words: " .. table.concat(list, ", "))
    end
end

-- -----------------------------------------------------------------------------
-- Profanity List Loading (Local txt files or Embedded Fallbacks)
-- -----------------------------------------------------------------------------
function load_list_file(filename)
    local user_dir = nil
    if vlc.config and vlc.config.userdatadir then
        local ok, res = pcall(vlc.config.userdatadir)
        if ok then user_dir = res end
    end
    
    local global_dir = nil
    if vlc.config and vlc.config.datadir then
        local ok, res = pcall(vlc.config.datadir)
        if ok then global_dir = res end
    end
    
    local f = nil
    if user_dir then
        user_dir = string.gsub(user_dir, "[\\/]+$", "")
        local full_path = user_dir .. "/lua/extensions/profanity_lists/" .. filename
        f = io.open(full_path, "r")
    end
    
    if not f and global_dir then
        global_dir = string.gsub(global_dir, "[\\/]+$", "")
        local full_path = global_dir .. "/lua/extensions/profanity_lists/" .. filename
        f = io.open(full_path, "r")
    end
    
    if not f then
        return nil -- Signals that we should use embedded fallback
    end
    
    local words = {}
    for line in f:lines() do
        -- Trim carriage returns, spaces, and ignore comments
        line = string.gsub(line, "\r", "")
        local word = string.gsub(line, "^%s*(.-)%s*$", "%1")
        word = string.lower(word)
        if word ~= "" and not string.find(word, "^#") then
            table.insert(words, word)
        end
    end
    f:close()
    return words
end

function build_active_list()
    active_profanity_set = {}
    local strictness = 3 -- Default Strict
    if strictness_dropdown then
        strictness = strictness_dropdown:get_value() or 3
    end
    
    local mild_list = load_list_file("mild.txt") or default_mild
    local standard_list = load_list_file("standard.txt") or default_standard
    local strict_list = load_list_file("strict.txt") or default_strict
    
    if strictness == 1 then
        -- Mild: Mild list only
        for _, w in ipairs(mild_list) do active_profanity_set[string.lower(w)] = true end
    elseif strictness == 2 then
        -- Standard: Mild + Standard
        for _, w in ipairs(mild_list) do active_profanity_set[string.lower(w)] = true end
        for _, w in ipairs(standard_list) do active_profanity_set[string.lower(w)] = true end
    elseif strictness == 3 then
        -- Strict: Mild + Standard + Strict
        for _, w in ipairs(mild_list) do active_profanity_set[string.lower(w)] = true end
        for _, w in ipairs(standard_list) do active_profanity_set[string.lower(w)] = true end
        for _, w in ipairs(strict_list) do active_profanity_set[string.lower(w)] = true end
    elseif strictness == 4 then
        -- Custom: Only custom words
    end
    
    -- Always merge custom user-defined words
    for w, _ in pairs(custom_words) do
        active_profanity_set[string.lower(w)] = true
    end
end

-- -----------------------------------------------------------------------------
-- Profanity Detection & Word Matching
-- -----------------------------------------------------------------------------
local normalization_map = {
    ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a", ["ā"] = "a",
    ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e", ["ē"] = "e",
    ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["ī"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o", ["ø"] = "o", ["ō"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["ū"] = "u",
    ["ÿ"] = "y", ["ñ"] = "n", ["ç"] = "c",
    ["!"] = "i", ["$"] = "s", ["@"] = "a", ["1"] = "i", ["0"] = "o"
}

local utf8_char_pattern = "[%z\x01-\x7f\xc2-\xf4][\x80-\xbf]*"

function normalize_word(w)
    w = string.lower(w)
    return (string.gsub(w, utf8_char_pattern, normalization_map))
end

function is_profane_word(sub_word, active_list)
    local norm_sub_word = normalize_word(sub_word)
    
    -- Direct exact match
    if active_list[norm_sub_word] then
        return true, norm_sub_word
    end
    
    -- Support masked substitutions (e.g. f***, f--k, sh*t, f#ck)
    if string.find(norm_sub_word, "[%*%-%_%#%?]") then
        local pattern_str = string.gsub(norm_sub_word, "[%*%-%_%#%?]", ".")
        pattern_str = "^" .. pattern_str .. "$"
        
        for word, _ in pairs(active_list) do
            if string.match(word, pattern_str) then
                return true, word
            end
        end
    end
    
    return false, nil
end

-- -----------------------------------------------------------------------------
-- Subtitle Timing Parser (.srt & .vtt)
-- -----------------------------------------------------------------------------
function parse_timing_line(line)
    -- HH:MM:SS,mmm or HH:MM:SS.mmm
    local sh, sm, ss, sms, eh, em, es, ems = string.match(line, "(%d+):(%d+):(%d+)[,%.](%d+)%s*-->%s*(%d+):(%d+):(%d+)[,%.](%d+)")
    if sh then
        local start_time = tonumber(sh) * 3600 + tonumber(sm) * 60 + tonumber(ss) + tonumber(sms) / 1000
        local end_time = tonumber(eh) * 3600 + tonumber(em) * 60 + tonumber(es) + tonumber(ems) / 1000
        return start_time, end_time
    end
    
    -- MM:SS,mmm or MM:SS.mmm (Short WebVTT format)
    local sm, ss, sms, em, es, ems = string.match(line, "(%d+):(%d+)[,%.](%d+)%s*-->%s*(%d+):(%d+)[,%.](%d+)")
    if sm then
        local start_time = tonumber(sm) * 60 + tonumber(ss) + tonumber(sms) / 1000
        local end_time = tonumber(em) * 60 + tonumber(es) + tonumber(ems) / 1000
        return start_time, end_time
    end
    
    return nil, nil
end

function parse_subtitle_file(filepath)
    local f, err = io.open(filepath, "r")
    if not f then
        return nil, "Could not open file: " .. tostring(err)
    end
    
    local subtitles = {}
    local current_sub = nil
    local state = "search" -- States: "search", "text"
    
    local is_first_line = true
    for line in f:lines() do
        if is_first_line then
            -- Strip UTF-8 BOM if present
            line = string.gsub(line, "^\xef\xbb\xbf", "")
            is_first_line = false
        end
        line = string.gsub(line, "\r", "")
        local trimmed = string.gsub(line, "^%s*(.-)%s*$", "%1")
        
        if state == "search" then
            -- Skip WebVTT file header
            if string.sub(trimmed, 1, 6) ~= "WEBVTT" then
                local start_time, end_time = parse_timing_line(trimmed)
                if start_time then
                    current_sub = {
                        start_time = start_time,
                        end_time = end_time,
                        lines = {}
                    }
                    state = "text"
                end
            end
        elseif state == "text" then
            if trimmed == "" then
                -- End of the subtitle block
                if current_sub and #current_sub.lines > 0 then
                    local clean_text = table.concat(current_sub.lines, " ")
                    clean_text = string.gsub(clean_text, "<[^>]+>", "") -- Strip HTML tags
                    clean_text = string.gsub(clean_text, "%s+", " ")     -- Strip duplicate spaces
                    current_sub.text = clean_text
                    current_sub.lines = nil
                    table.insert(subtitles, current_sub)
                end
                current_sub = nil
                state = "search"
            else
                -- Check for inline timing in case file is malformed
                local start_time, end_time = parse_timing_line(trimmed)
                if start_time then
                    if current_sub and #current_sub.lines > 0 then
                        local clean_text = table.concat(current_sub.lines, " ")
                        clean_text = string.gsub(clean_text, "<[^>]+>", "")
                        clean_text = string.gsub(clean_text, "%s+", " ")
                        current_sub.text = clean_text
                        current_sub.lines = nil
                        table.insert(subtitles, current_sub)
                    end
                    current_sub = {
                        start_time = start_time,
                        end_time = end_time,
                        lines = {}
                    }
                else
                    -- Filter subtitle block sequence numbers
                    local is_seq_num = string.match(trimmed, "^%d+$")
                    if is_seq_num and #current_sub.lines == 0 then
                        -- Skip
                    else
                        table.insert(current_sub.lines, trimmed)
                    end
                end
            end
        end
    end
    
    -- Close final block if file ended without newline
    if current_sub and current_sub.lines and #current_sub.lines > 0 then
        local clean_text = table.concat(current_sub.lines, " ")
        clean_text = string.gsub(clean_text, "<[^>]+>", "")
        clean_text = string.gsub(clean_text, "%s+", " ")
        current_sub.text = clean_text
        current_sub.lines = nil
        table.insert(subtitles, current_sub)
    end
    
    f:close()
    return subtitles
end

-- -----------------------------------------------------------------------------
-- Mute Window Generator
-- -----------------------------------------------------------------------------
local function serialize_mute_windows(windows)
    local ranges = {}
    for _, win in ipairs(windows) do
        table.insert(ranges, string.format("%.3f-%.3f", win.start_time, win.end_time))
    end
    return table.concat(ranges, ";")
end

function rebuild_mute_windows()
    if #loaded_subtitles == 0 then
        mute_windows = {}
        detected_count = 0
        local pl = vlc.object.playlist()
        if pl then
            pcall(vlc.var.set, pl, "cleanplay-v1-mute-windows", "")
        end
        update_preview_list()
        update_ui()
        return
    end
    
    local pre_buf = 0.3
    if pre_buffer_input then
        pre_buf = tonumber(pre_buffer_input:get_text()) or 0.3
    end
    
    local post_buf = 0.2
    if post_buffer_input then
        post_buf = tonumber(post_buffer_input:get_text()) or 0.2
    end
    
    local offset = 0.0
    if offset_input then
        offset = tonumber(offset_input:get_text()) or 0.0
    end
    
    local word_level = false
    if word_level_checkbox then
        word_level = word_level_checkbox:get_checked()
    end
    
    local raw_windows = {}
    local profanity_count = 0
    
    for _, sub in ipairs(loaded_subtitles) do
        local is_profane = false
        local matched = {}
        
        for w in string.gmatch(sub.text, "[%w%*%-%_%!%$%@%#%?]+") do
            local found, word = is_profane_word(w, active_profanity_set)
            if found then
                is_profane = true
                matched[word] = true
            end
        end
        
        if is_profane then
            profanity_count = profanity_count + 1
            local list_matched = {}
            for w, _ in pairs(matched) do
                table.insert(list_matched, w)
            end
            
            if word_level then
                -- Calculate approximate start/end for the exact profane word(s)
                local words = {}
                for w in string.gmatch(sub.text, "[%w%*%-%_%!%$%@%#%?]+") do
                    table.insert(words, w)
                end
                
                local num_words = #words
                local duration = sub.end_time - sub.start_time
                
                for i, w in ipairs(words) do
                    local found, word = is_profane_word(w, active_profanity_set)
                    if found then
                        local word_start = sub.start_time + (i - 1) / num_words * duration
                        local word_end = sub.start_time + i / num_words * duration
                        
                        table.insert(raw_windows, {
                            start_time = word_start + offset - pre_buf,
                            end_time = word_end + offset + post_buf,
                            text = "\"" .. w .. "\" in: " .. sub.text,
                            matched_words = { word }
                        })
                    end
                end
            else
                -- Mute the whole subtitle block timing
                table.insert(raw_windows, {
                    start_time = sub.start_time + offset - pre_buf,
                    end_time = sub.end_time + offset + post_buf,
                    text = sub.text,
                    matched_words = list_matched
                })
            end
        end
    end
    
    if #raw_windows == 0 then
        mute_windows = {}
        detected_count = 0
        local pl = vlc.object.playlist()
        if pl then
            pcall(vlc.var.set, pl, "cleanplay-v1-mute-windows", "")
        end
        update_preview_list()
        update_ui()
        set_message("<span style='color:green;'>Analysis complete. No profanity found.</span>")
        return
    end
    
    -- Sort by start time
    table.sort(raw_windows, function(a, b) return a.start_time < b.start_time end)
    
    -- Merge overlapping windows
    local merged = {}
    local current = raw_windows[1]
    
    for i = 2, #raw_windows do
        local next_win = raw_windows[i]
        if next_win.start_time <= current.end_time then
            current.end_time = math.max(current.end_time, next_win.end_time)
            
            -- Merge matched word lists uniquely
            for _, w in ipairs(next_win.matched_words) do
                local found = false
                for _, cw in ipairs(current.matched_words) do
                    if cw == w then found = true; break end
                end
                if not found then
                    table.insert(current.matched_words, w)
                end
            end
            current.text = current.text .. " | " .. next_win.text
        else
            table.insert(merged, current)
            current = next_win
        end
    end
    table.insert(merged, current)
    
    mute_windows = merged
    detected_count = profanity_count
    
    local pl = vlc.object.playlist()
    if pl then
        local windows_str = serialize_mute_windows(mute_windows)
        pcall(vlc.var.set, pl, "cleanplay-v1-mute-windows", windows_str)
    end
    
    update_preview_list()
    update_ui()
    set_message("<span style='color:green;'>Analysis complete! Filter updated.</span>")
end

function update_preview_list()
    if not preview_list then return end
    preview_list:clear()
    
    for i, win in ipairs(mute_windows) do
        if i > 50 then
            preview_list:add_value("... and " .. (#mute_windows - 50) .. " more", 999)
            break
        end
        local time_str = format_time(win.start_time)
        local words_str = table.concat(win.matched_words, ", ")
        preview_list:add_value("[" .. time_str .. "] Mute: " .. words_str, i)
    end
end

function format_time(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    local ms = math.floor((secs - math.floor(secs)) * 1000)
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

-- -----------------------------------------------------------------------------
-- Playback Monitoring & Muting Logic
-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- Track Change Detection
-- -----------------------------------------------------------------------------
function check_track_changes()
    local input = vlc.object.input()
    if not input then return end
    
    local item = vlc.input.item()
    if item then
        local uri = item:uri()
        if uri and uri ~= "" then
            local decoded_path = uri_to_path(uri)
            
            local active_id = vlc.var.get(input, "spu-es") or -1
            
            if decoded_path ~= current_loaded_media_path or active_id ~= current_loaded_spu_id then
                current_loaded_media_path = decoded_path
                current_loaded_spu_id = active_id
                
                if active_id > 0 then
                    autoload_subtitle_for_track(decoded_path, active_id, true)
                else
                    loaded_subtitles = {}
                    rebuild_mute_windows()
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Settings Application and Manual Refresh
-- -----------------------------------------------------------------------------
function apply_settings_clicked()
    build_active_list()
    rebuild_mute_windows()
    
    local pl = vlc.object.playlist()
    if pl then
        local is_enabled = "false"
        if enable_checkbox and enable_checkbox:get_checked() then
            is_enabled = "true"
        end
        pcall(vlc.var.set, pl, "cleanplay-v1-enabled", is_enabled)
    end
    
    update_ui()
    set_message("<span style='color:green;'>Settings applied.</span>")
end

function refresh_status_clicked()
    check_track_changes()
    update_ui()
    set_message("Status refreshed.")
end

-- Compatibility Stubs
function apply_mute(should_mute)
end

-- -----------------------------------------------------------------------------
-- Button Callbacks
-- -----------------------------------------------------------------------------
function load_subtitle_clicked()
    local path = file_input:get_text()
    if path == "" then
        set_message("<span style='color:red;'>Error: Please enter a subtitle file path.</span>")
        return
    end
    load_subtitle_file(path)
end

function load_subtitle_file(path)
    -- Clean quotes from copy-pasting paths
    path = string.gsub(path, '^["\']', '')
    path = string.gsub(path, '["\']$', '')
    
    set_message("Loading file: " .. path)
    
    local subs, err = parse_subtitle_file(path)
    if not subs then
        set_message("<span style='color:red;'>Error: " .. tostring(err) .. "</span>")
        return
    end
    
    loaded_subtitles = subs
    set_message("<span style='color:green;'>Loaded " .. #subs .. " subtitles. Analysing...</span>")
    
    build_active_list()
    rebuild_mute_windows()
end

function autoload_clicked()
    autoload_subtitle(false)
end

-- Helper to check if a decoded VINT size is unknown (all data bits are 1s)
local function is_vint_unknown(val, num_bytes)
    if not val or not num_bytes then return false end
    local max_val = 1
    for i = 1, 7 * num_bytes do
        max_val = max_val * 2
    end
    max_val = max_val - 1
    return val == max_val
end

-- Helper to identify top-level Segment children
local function is_top_level_element(id)
    return id == 0x1F43B675  -- Cluster
        or id == 0x1549A966  -- Info
        or id == 0x1654AE6B  -- Tracks
        or id == 0x1C53BB6B  -- Cues
        or id == 0x114D9B74  -- SeekHead
        or id == 0x1254C367  -- Tags
        or id == 0x1941A469  -- Attachments
        or id == 0x1B538667  -- Signature
end

-- Helper function to read variable-size integers representing EBML IDs
local function read_id(f)
    local b1 = f:read(1)
    if not b1 then return nil end
    local byte = string.byte(b1)
    
    local num_bytes = 1
    if byte >= 128 then num_bytes = 1
    elseif byte >= 64 then num_bytes = 2
    elseif byte >= 32 then num_bytes = 3
    elseif byte >= 16 then num_bytes = 4
    elseif byte >= 8 then num_bytes = 5
    elseif byte >= 4 then num_bytes = 6
    elseif byte >= 2 then num_bytes = 7
    elseif byte >= 1 then num_bytes = 8
    else return nil end
    
    local val = byte
    for i = 2, num_bytes do
        local b = f:read(1)
        if not b then return nil end
        val = val * 256 + string.byte(b)
    end
    return val
end

-- Helper function to read EBML Variable Size Integers (VINT)
local function read_vint(f)
    local b1 = f:read(1)
    if not b1 then return nil, nil end
    local byte = string.byte(b1)
    
    local num_bytes = 1
    local val = byte
    
    if byte >= 128 then
        num_bytes = 1
        val = byte - 128
    elseif byte >= 64 then
        num_bytes = 2
        val = byte - 64
    elseif byte >= 32 then
        num_bytes = 3
        val = byte - 32
    elseif byte >= 16 then
        num_bytes = 4
        val = byte - 16
    elseif byte >= 8 then
        num_bytes = 5
        val = byte - 8
    elseif byte >= 4 then
        num_bytes = 6
        val = byte - 4
    elseif byte >= 2 then
        num_bytes = 7
        val = byte - 2
    elseif byte >= 1 then
        num_bytes = 8
        val = byte - 1
    else
        return nil, nil
    end
    
    for i = 2, num_bytes do
        local b = f:read(1)
        if not b then return nil, nil end
        val = val * 256 + string.byte(b)
    end
    
    return val, num_bytes
end

-- Parses an EBML element structure recursively or iteratively, handling unknown sizes
local function parse_ebml(f, end_pos, callback, stop_on_top_level)
    while true do
        local current_pos = f:seek()
        if end_pos and current_pos >= end_pos then
            break
        end
        
        local id_pos = current_pos
        local id = read_id(f)
        if not id then break end
        
        if stop_on_top_level and is_top_level_element(id) then
            -- Seek back to the start of this top-level element so parent can read it
            f:seek("set", id_pos)
            break
        end
        
        local size, size_len = read_vint(f)
        if not size then break end
        
        local is_unknown = is_vint_unknown(size, size_len)
        local data_pos = f:seek()
        local next_pos = is_unknown and nil or (data_pos + size)
        
        local stop = callback(id, size, data_pos, f, is_unknown)
        if stop then
            return stop
        end
        
        if next_pos then
            f:seek("set", next_pos)
        else
            -- Unknown size element. The callback is expected to have parsed children
            -- sequentially, or we just parse next elements from current file position.
        end
    end
end

-- Finds the track number of the subtitle track at target_index in an MKV file
local function find_subtitle_track(f, segment_end, target_index)
    local found_track_num = nil
    local found_codec_id = nil
    local current_subtitle_index = 0
    
    parse_ebml(f, segment_end, function(id, size, data_pos, f, is_unknown)
        if id == 0x1654AE6B then -- Tracks
            f:seek("set", data_pos)
            local tracks_end = is_unknown and nil or (data_pos + size)
            parse_ebml(f, tracks_end, function(id, size, data_pos, f, is_unknown)
                if id == 0xAE then -- TrackEntry
                    local track_num = nil
                    local track_type = nil
                    local codec = nil
                    
                    f:seek("set", data_pos)
                    local entry_end = is_unknown and nil or (data_pos + size)
                    parse_ebml(f, entry_end, function(id, size, data_pos)
                        if id == 0xD7 then -- TrackNumber
                            local b = f:read(size)
                            if b then
                                local n = 0
                                for i = 1, #b do
                                    n = n * 256 + string.byte(b, i)
                                end
                                track_num = n
                            end
                        elseif id == 0x83 then -- TrackType
                            local b = f:read(size)
                            if b then
                                local n = 0
                                for i = 1, #b do
                                    n = n * 256 + string.byte(b, i)
                                end
                                track_type = n
                            end
                        elseif id == 0x86 then -- CodecID
                            codec = f:read(size)
                            if codec then
                                codec = string.gsub(codec, "%z", "") -- Strip null terminators
                                codec = string.upper(codec)         -- Case-insensitive
                            end
                        end
                    end)
                    
                    if track_type == 17 then
                        current_subtitle_index = current_subtitle_index + 1
                        if codec == "S_TEXT/UTF8" or codec == "S_TEXT/ASS" or codec == "S_TEXT/SSA" or codec == "S_TEXT/WEBVTT" or codec == "S_ASS" or codec == "S_SSA" then
                            if not target_index or current_subtitle_index == target_index then
                                found_track_num = track_num
                                found_codec_id = codec
                                return true
                            end
                        end
                    end
                end
            end, true) -- Stop on top level inside Tracks
            if found_track_num then return true end
        end
    end, false) -- Stop on top level inside Segment (false for segment-level loop)
    
    return found_track_num, found_codec_id
end

-- Extracts subtitle tracks from MKV directly in pure Lua (100% self-contained)
local function extract_subtitles_pure_lua(mkv_path, out_srt_path, target_index)
    local f, err = io.open(mkv_path, "rb")
    if not f then
        return nil, "Could not open file: " .. tostring(err)
    end
    
    local header_id = read_id(f)
    if header_id ~= 0x1A45DFA3 then
        f:close()
        return nil, "Not a valid EBML/MKV file."
    end
    
    f:seek("set", 0)
    local segment_pos = nil
    local segment_size = nil
    local segment_is_unknown = false
    
    parse_ebml(f, nil, function(id, size, data_pos, f, is_unknown)
        if id == 0x18538067 then -- Segment
            segment_pos = data_pos
            segment_size = size
            segment_is_unknown = is_unknown
            return true
        end
    end)
    
    if not segment_pos then
        f:close()
        return nil, "Segment element not found."
    end
    
    local segment_end = nil
    if not segment_is_unknown and segment_size then
        segment_end = segment_pos + segment_size
    end
    
    -- 1. Find Subtitle Track Number and Codec
    f:seek("set", segment_pos)
    local sub_track_num, codec_id = find_subtitle_track(f, segment_end, target_index)
    if not sub_track_num then
        f:close()
        return nil, "No SRT or ASS subtitle track found at index " .. tostring(target_index or 1)
    end
    
    -- 2. Scan Clusters and extract blocks
    local subtitles_list = {}
    
    f:seek("set", segment_pos)
    parse_ebml(f, segment_end, function(id, size, data_pos, f, is_unknown)
        if id == 0x1F43B675 then -- Cluster
            local cluster_timecode = 0
            
            f:seek("set", data_pos)
            local cluster_end = is_unknown and nil or (data_pos + size)
            parse_ebml(f, cluster_end, function(id, size, data_pos, f, is_unknown)
                if id == 0xE7 then -- Cluster Timecode
                    local b = f:read(size)
                    if b then
                        local n = 0
                        for i = 1, #b do
                            n = n * 256 + string.byte(b, i)
                        end
                        cluster_timecode = n
                    end
                elseif id == 0xA3 then -- SimpleBlock
                    local track_num, track_num_len = read_vint(f)
                    if track_num == sub_track_num then
                        local b_tc = f:read(2)
                        if b_tc and #b_tc == 2 then
                            local tc = string.byte(b_tc, 1) * 256 + string.byte(b_tc, 2)
                            if tc >= 32768 then tc = tc - 65536 end
                            local block_time = cluster_timecode + tc
                            f:read(1) -- flags
                            
                            local text_len = size - track_num_len - 3
                            if text_len > 0 then
                                local text = f:read(text_len)
                                if text then
                                    table.insert(subtitles_list, {
                                        start_time = block_time / 1000,
                                        text = text
                                    })
                                end
                            end
                        end
                    end
                elseif id == 0xA0 then -- BlockGroup
                    local block_data = nil
                    local duration = nil
                    
                    f:seek("set", data_pos)
                    local group_end = is_unknown and nil or (data_pos + size)
                    parse_ebml(f, group_end, function(id, size, data_pos, f, is_unknown)
                        if id == 0xA1 then -- Block
                            local track_num, track_num_len = read_vint(f)
                            if track_num == sub_track_num then
                                local b_tc = f:read(2)
                                if b_tc and #b_tc == 2 then
                                    local tc = string.byte(b_tc, 1) * 256 + string.byte(b_tc, 2)
                                    if tc >= 32768 then tc = tc - 65536 end
                                    local block_time = cluster_timecode + tc
                                    f:read(1) -- flags
                                    local text_len = size - track_num_len - 3
                                    if text_len > 0 then
                                        local text = f:read(text_len)
                                        if text then
                                            block_data = {
                                                start_time = block_time / 1000,
                                                text = text
                                            }
                                        end
                                    end
                                end
                            end
                        elseif id == 0x9B then -- BlockDuration
                            local b = f:read(size)
                            if b then
                                local n = 0
                                for i = 1, #b do
                                    n = n * 256 + string.byte(b, i)
                                end
                                duration = n / 1000
                            end
                        end
                    end, true) -- Stop on top level inside BlockGroup
                    
                    if block_data then
                        if duration then
                            block_data.end_time = block_data.start_time + duration
                        end
                        table.insert(subtitles_list, block_data)
                    end
                end
            end, true) -- Stop on top level inside Cluster
        end
    end, false) -- Stop on top level inside Segment (false for segment-level loop)
    
    f:close()
    
    if #subtitles_list == 0 then
        return nil, "No subtitle blocks found."
    end
    
    -- Calculate durations for blocks without explicit end time
    for i = 1, #subtitles_list do
        local sub = subtitles_list[i]
        if not sub.end_time then
            local next_sub = subtitles_list[i+1]
            local max_duration = 3.0 + string.len(sub.text) * 0.05
            if next_sub then
                sub.end_time = math.min(next_sub.start_time, sub.start_time + max_duration)
            else
                sub.end_time = sub.start_time + max_duration
            end
        end
    end
    
    -- Open output file
    local out_f, oerr = io.open(out_srt_path, "w")
    if not out_f then
        return nil, "Could not create SRT file: " .. tostring(oerr)
    end
    
    for i, sub in ipairs(subtitles_list) do
        local text = sub.text
        if codec_id == "S_TEXT/ASS" or codec_id == "S_TEXT/SSA" or codec_id == "S_ASS" or codec_id == "S_SSA" then
            local commas = 0
            local text_start = 1
            for j = 1, #text do
                if string.sub(text, j, j) == "," then
                    commas = commas + 1
                    if commas == 8 then
                        text_start = j + 1
                        break
                    end
                end
            end
            text = string.sub(text, text_start)
        end
        
        -- Clean ASS tags and formatting
        text = string.gsub(text, "{[^}]+}", "")
        text = string.gsub(text, "\\N", "\n")
        text = string.gsub(text, "\r", "")
        
        local start_str = format_time(sub.start_time)
        local end_str = format_time(sub.end_time)
        
        out_f:write(tostring(i) .. "\n")
        out_f:write(start_str .. " --> " .. end_str .. "\n")
        out_f:write(text .. "\n\n")
    end
    
    out_f:close()
    return true
end

-- Fallback wrapper that tries pure Lua first, then external tools
function try_extract_subtitles(video_path, target_srt_path, target_index)
    vlc.msg.info("CleanPlay: Attempting direct pure-Lua subtitle extraction for track " .. tostring(target_index or 1) .. "...")
    local ok, success, err = pcall(extract_subtitles_pure_lua, video_path, target_srt_path, target_index)
    if ok and success then
        vlc.msg.info("CleanPlay: Direct pure-Lua subtitle extraction succeeded!")
        return true, nil
    else
        local errMsg = tostring(success or err)
        vlc.msg.warn("CleanPlay: Direct pure-Lua extraction failed: " .. errMsg)
        
        -- Sanitize paths to prevent command injection (remove any double quotes)
        local safe_video_path = string.gsub(video_path, '"', '')
        local safe_target_srt_path = string.gsub(target_srt_path, '"', '')
        
        -- Fall back to ffmpeg
        vlc.msg.info("CleanPlay: Falling back to silent FFmpeg background extraction...")
        local map_idx = (target_index or 1) - 1
        local cmd = string.format('ffmpeg -y -i "%s" -map 0:s:%d -c:s srt "%s"', safe_video_path, map_idx, safe_target_srt_path)
        
        local handle = io.popen(cmd)
        if handle then
            handle:read("*all")
            handle:close()
        end
        
        local f = io.open(target_srt_path, "r")
        if f then
            f:close()
            return true, nil
        end
        
        -- Fall back to mkvextract
        vlc.msg.info("CleanPlay: Falling back to silent mkvextract background extraction...")
        local cmd_mkv = string.format('mkvextract tracks "%s" %d:"%s"', safe_video_path, target_index or 2, safe_target_srt_path)
        handle = io.popen(cmd_mkv)
        if handle then
            handle:read("*all")
            handle:close()
        end
        
        f = io.open(target_srt_path, "r")
        if f then
            f:close()
            return true, nil
        end
        
        return false, errMsg
    end
end

-- Helper to map active SPU ID to 1-based subtitle index and get the track label
local function get_active_spu_index(input, active_id)
    if not input or not active_id or active_id <= 0 then
        return nil, nil
    end
    local values, labels = vlc.var.get_list(input, "spu-es")
    if not values or not labels then
        return nil, nil
    end
    
    local subtitle_track_index = 0
    local label = nil
    for i, val in ipairs(values) do
        if val > 0 then
            subtitle_track_index = subtitle_track_index + 1
            if val == active_id then
                label = labels[i]
                return subtitle_track_index, label
            end
        end
    end
    return nil, nil
end

-- Autoloads the subtitle for the specific active SPU track
function autoload_subtitle_for_track(path, active_id, quiet)
    local input = vlc.object.input()
    if not input then return end
    
    local track_index, label = get_active_spu_index(input, active_id)
    if not track_index then
        if not quiet then
            set_message("<span style='color:red;'>Error: Could not retrieve active subtitle track index.</span>")
        end
        return
    end
    
    local base_path = string.match(path, "(.+)%.[^%.]+$") or path
    local base_dir = string.match(path, "(.+)[\\/][^\\/]+$") or ""
    
    -- Check if this is an external subtitle track (label typically contains extension)
    local is_external = false
    if label then
        local lower_label = string.lower(label)
        if string.find(lower_label, "%.srt") or string.find(lower_label, "%.vtt") then
            is_external = true
        end
    end
    
    if is_external and label then
        local sub_path = label
        if not string.find(label, "^[a-zA-Z]:") and not string.find(label, "^/") then
            sub_path = base_dir .. "/" .. label
        end
        sub_path = string.gsub(sub_path, "\\", "/")
        
        local f = io.open(sub_path, "r")
        if f then
            f:close()
            if file_input then file_input:set_text(sub_path) end
            load_subtitle_file(sub_path)
            return
        end
    end
    
    -- Try extraction from video container (MKV, MP4, etc.)
    local ext = string.match(path, "%.([%w]+)$")
    if ext then
        ext = string.lower(ext)
        if ext == "mkv" or ext == "mp4" or ext == "m4v" then
            local target_srt_path = base_path .. "." .. tostring(track_index) .. ".srt"
            if not quiet then
                set_message("No external file. Extracting internal track " .. tostring(track_index) .. "...")
            end
            
            local extracted, err_msg = try_extract_subtitles(path, target_srt_path, track_index)
            if extracted then
                if file_input then file_input:set_text(target_srt_path) end
                load_subtitle_file(target_srt_path)
                return
            else
                if not quiet then
                    set_message("<span style='color:red;'>Autoload failed: " .. tostring(err_msg) .. "</span>")
                end
                return
            end
        end
    end
    
    if not quiet then
        set_message("<span style='color:red;'>Autoload failed. No matching track found or extraction failed.</span>")
    end
end

-- Public autoload method (called from Load button or interface hook)
function autoload_subtitle(quiet)
    local item = vlc.input.item()
    if not item then
        if not quiet then
            set_message("<span style='color:red;'>Error: No video is playing.</span>")
        end
        return
    end
    
    local uri = item:uri()
    if not uri or uri == "" then
        if not quiet then
            set_message("<span style='color:red;'>Error: Could not retrieve media location.</span>")
        end
        return
    end
    
    local path = uri_to_path(uri)
    
    local input = vlc.object.input()
    local active_id = -1
    if input then
        active_id = vlc.var.get(input, "spu-es") or -1
    end
    
    if active_id > 0 then
        autoload_subtitle_for_track(path, active_id, quiet)
    else
        -- Fallback: If no active track is selected, look for a matching external file in the dir
        local base_path = string.match(path, "(.+)%.[^%.]+$") or path
        local suffixes = { ".srt", ".vtt", ".en.srt", ".en.vtt", ".eng.srt", ".eng.vtt" }
        for _, suffix in ipairs(suffixes) do
            local sub_path = base_path .. suffix
            local f = io.open(sub_path, "r")
            if f then
                f:close()
                if file_input then file_input:set_text(sub_path) end
                load_subtitle_file(sub_path)
                return
            end
        end
        
        if not quiet then
            set_message("<span style='color:red;'>Autoload failed. Subtitles disabled in VLC and no external file found.</span>")
        end
    end
end

function add_word_clicked()
    if not add_word_input then return end
    local word = add_word_input:get_text()
    if word == "" then return end
    
    word = string.gsub(word, "^%s*(.-)%s*$", "%1") -- Trim
    word = string.lower(word)
    
    if word ~= "" then
        custom_words[word] = true
        save_custom_words()
        update_custom_words_display()
        add_word_input:set_text("")
        set_message("Added word: '" .. word .. "'")
        
        build_active_list()
        rebuild_mute_windows()
    end
end

function remove_word_clicked()
    if not add_word_input then return end
    local word = add_word_input:get_text()
    if word == "" then return end
    
    word = string.gsub(word, "^%s*(.-)%s*$", "%1") -- Trim
    word = string.lower(word)
    
    if word ~= "" then
        if custom_words[word] then
            custom_words[word] = nil
            save_custom_words()
            update_custom_words_display()
            add_word_input:set_text("")
            set_message("Removed word: '" .. word .. "'")
            
            build_active_list()
            rebuild_mute_windows()
        else
            set_message("Word '" .. word .. "' not found in custom list.")
        end
    end
end
