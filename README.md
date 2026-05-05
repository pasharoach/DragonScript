# DragonScript for DaVinci Resolve

[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS-111111?logo=apple&logoColor=white)](#installation-macos)
[![Version](https://img.shields.io/badge/Version-3.0-FF8A00)](#changelog)
[![Status](https://img.shields.io/badge/Status-Final%20Release-0A7D32)](#project-status)
[![License: MIT](https://img.shields.io/badge/License-MIT-0E8A16.svg)](LICENSE)

[Русская версия](README.ru.md)

![DragonScript banner](assets/banner.svg)

Read your script inside DaVinci Resolve and jump the playhead to any timecode in one click — without leaving the app.

DragonScript is a lightweight Lua utility for DaVinci Resolve / Fusion. It opens text documents in a floating panel, highlights SMPTE timecodes in the text, and moves the playhead when you click a timecode in the right-side list.

---

## Project Status

DragonScript v3.0 is the final stable release of this project.

---

## Highlights

- **No app switching** — script and timeline live in the same window.
- **Timecode sidebar** — all detected TCs listed on the right with a context preview.
- **One-click jump** — click any timecode in the sidebar to move the playhead instantly.
- **SET TC** — stamp the current Resolve timeline position right into your text.
- **Refresh button** — manually rebuild the right sidebar after text edits.
- **Save As** — always exports clean `.txt`, no matter the source format.

---

## Features

| Feature | Detail |
|---|---|
| File formats | `.txt` `.fountain` `.md` `.srt` `.fdx` `.docx` `.doc` `.rtf` `.odt` `.pages` |
| SMPTE formats | `HH:MM:SS:FF` and `HH:MM:SS;FF` (drop-frame) |
| Timecode sidebar | Lists every TC with up to 7 words of following context |
| Click to jump | Click a TC in the sidebar → playhead jumps immediately |
| SET TC | Inserts current timeline timecode at the text cursor |
| Refresh | Rebuilds highlighted text + right sidebar from current editor text |
| Font size | Adjustable 8 – 36 pt |
| Save As | Exports as `.txt` |

---

## Installation (macOS)

**1.** Copy `DragonScript.lua` to the Resolve Fusion scripts folder:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

Open the folder from Terminal:

```bash
open "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/"
```

**2.** Run the script inside DaVinci Resolve:

```text
Workspace → Scripts → Utility → DragonScript
```

Resolve restart is usually not required.

---

## Usage

### Reading a script

1. Click **Open…** and choose a script or notes file.
2. SMPTE timecodes are highlighted in orange in the text.
3. All detected timecodes appear in the **right sidebar** with a short context preview.

### Jumping the playhead

- **Click any timecode in the sidebar** → playhead moves to that position immediately.

### Stamping the current position

- Click **SET TC** to insert the current Resolve timeline timecode at the cursor position in the text.  
  The inserted timecode appears in the sidebar after refresh.

### Refreshing after edits

- After editing text, click **Refresh** to update highlighted text and the right sidebar context.

### Editing

- Click **Save As…** to export the current text as `.txt`.

---

## Built For

- Editors working with scripted or cue-annotated timelines.
- Directors and ADs reviewing production notes with timecodes.
- Script supervisors who need everything inside one app.

---

## Technical Notes

- **Language:** Lua 5.1 (Fusion scripting inside DaVinci Resolve)
- **UI:** Fusion `UIManager` / `bmd.UIDispatcher`
- **Resolve API:** `Resolve()` → `GetCurrentTimeline()` → `SetCurrentTimecode()`
- **Platform:** macOS (tested on DaVinci Resolve 18 / 19)

---

## Changelog

- **3.0**
- Finalized UI for production use
- Added manual **Refresh** workflow for right sidebar updates
- Simplified control set (removed Jump TC / Go)
- Stabilized Save As `.txt` behavior

---

## License

Released under the MIT License. See [LICENSE](LICENSE).
