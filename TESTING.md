# CleanPlay Testing Procedures

This document outlines the testing scenarios to verify that the subtitle parsing, profanity matching, mute window generation, and audio control are working correctly.

## 1. Subtitle Parser Testing
Verify that `.srt` and `.vtt` formats are parsed accurately.

### Test Case 1.1: Standard SRT File
- **Input**: `examples/sample.srt`
- **Steps**:
  1. Open the CleanPlay extension.
  2. Paste the absolute path of `examples/sample.srt` in the text box.
  3. Click **Load Subtitle**.
- **Expected Result**: 
  - Status message shows `Loaded 8 subtitles`.
  - Preview list displays the list of upcoming mute events with correct timestamps.

### Test Case 1.2: WebVTT (.vtt) Timing Formats
- **Input**: Create a WebVTT file with format `MM:SS.mmm` instead of `HH:MM:SS,mmm`.
- **Expected Result**: The parser successfully recognizes the WebVTT header and parses timestamps like `01:02.300 --> 01:04.800` into correct numerical seconds.

---

## 2. Profanity Detection Testing
Verify word matching under different strictness settings.

### Test Case 2.1: Strictness Presets
- **Mild Settings**:
  - Select **Mild** in the dropdown list.
  - Load `examples/sample.srt`.
  - **Expected Result**: Only Subtitle 2 (`hell`, `damn`) is detected. Mute count = 1.
- **Standard Settings**:
  - Select **Standard** in the dropdown list.
  - Load `examples/sample.srt`.
  - **Expected Result**: Subtitles 2 (`hell`, `damn`) and 4 (`shit`, `ass`) are detected. Mute count = 2.
- **Strict Settings**:
  - Select **Strict** in the dropdown list.
  - Load `examples/sample.srt`.
  - **Expected Result**: Subtitles 2, 4, 6 (`fuck`, `cunt`), and 7 (`f***`, `sh!t`, `a$$`) are detected. Mute count = 4.

### Test Case 2.2: Masked Word Normalization
- **Expected Result**: Subtitle 7 containing `f***`, `sh!t`, and `a$$` must be successfully matched when strictness is set to **Strict**, proving the symbol mappings and wildcard regex logic are working.
- **False Positive Test**: Verify that subtitle text containing words like "class", "assume", "basement", or "shell" does not trigger muting for "ass" or "hell".

### Test Case 2.3: Custom Add/Remove
- **Steps**:
  1. Set Strictness to **Custom**. (Mute count drops to 0).
  2. Type `lazy` in the **Custom Word** text input and click **Add Word**.
  3. **Expected Result**: "lazy" appears under custom words. Mute count increases to 1 (matching Subtitle 4).
  4. Type `lazy` again and click **Remove Word**.
  5. **Expected Result**: Word is removed and mute count goes back to 0.

---

## 3. Playback and Volume Muting Testing
Verify real-time mute triggers, seeking, and manual override handling.

### Test Case 3.1: Playback Mute / Unmute
- **Steps**:
  1. Open a video in VLC.
  2. Load `examples/sample.srt`. Set strictness to **Strict**.
  3. Let the video play.
- **Expected Result**: 
  - As time approaches `00:00:06.700` (7.0s - 0.3s pre-buffer), VLC volume sets to `0`. UI shows `MUTED`.
  - At `00:00:10.500` (10.0s + 0.5s post-buffer), volume restores to the original level. UI shows `Not muted`.

### Test Case 3.2: Manual Volume Adjustments
- **Steps**:
  1. During a clean segment, set volume to 50% (128). Let a mute window trigger (volume drops to 0).
  2. During the mute window, raise the volume to 80% (204).
- **Expected Result**: 
  - The extension immediately clamps the volume back to 0 (to filter the audio).
  - When the mute window ends, the volume is restored to **80%** (the new manual override level).

### Test Case 3.3: Playback Seeking
- **Steps**:
  1. Play a clean segment.
  2. Manually drag the VLC playback slider into the middle of a profane segment (e.g., `00:00:28.000`).
- **Expected Result**: The extension detects the seek event via `"intf-event"` instantly and mutes the audio without waiting.
  3. Seek back to a clean segment (e.g., `00:00:03.000`).
- **Expected Result**: The extension unmutes the audio instantly.
