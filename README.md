# ScriptViewer for DaVinci Resolve

[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS-111111?logo=apple&logoColor=white)](#installation-macos)
[![Status](https://img.shields.io/badge/Status-Active%20Development-0A7D32)](#roadmap)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-1F6FEB)](#contributing)

[Русская версия](README.ru.md)

![ScriptViewer banner](assets/banner.svg)

Read scripts inside Resolve and jump to exact moments with one click.

ScriptViewer is a lightweight Lua utility for DaVinci Resolve/Fusion that opens text documents in a dedicated panel, highlights SMPTE timecodes, and moves the playhead when you click them.

## Highlights

- No app switching: keep your script and timeline in the same workspace.
- Clickable SMPTE timecodes for fast timeline navigation.
- View/Edit workflow for quick in-app text fixes.
- Save As always exports plain text `.txt`.
- Supports common screenplay and production note formats.

## Features

- File support: `.txt`, `.fountain`, `.md`, `.srt`, `.fdx`, `.docx`, `.doc`, `.rtf`, `.odt`, `.pages`.
- SMPTE detection:
  - `HH:MM:SS:FF`
  - `HH:MM:SS;FF`
- Click-to-jump playhead navigation.
- View/Edit mode toggle.
- Font size control (8-36).
- Save As export to `.txt`.

## Installation (macOS)

1. Copy `ScriptViewer.lua` to:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

2. Start DaVinci Resolve and run:

```text
Workspace -> Scripts -> Utility -> ScriptViewer
```

3. Resolve restart is usually not required.

Quick open target folder from Terminal:

```bash
open "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/"
```

## Usage

1. Click Open... and select your script file.
2. Click any SMPTE timecode to move the playhead.
3. Use Edit to modify text and View to return to clickable mode.
4. Use Save As... to export the current content as `.txt`.

## Built For

- Editors working with scripted timelines.
- Directors and assistants reviewing cue/timecode notes.
- Script supervisor workflows that need everything inside Resolve.

## Technical Notes

- Language: Lua 5.1 (Fusion scripting).
- UI: Fusion UIManager.
- Integration: Resolve API (`Resolve()`, timeline navigation).

## Roadmap

- [ ] In-document text search
- [ ] Drag and drop file support
- [ ] Timecode bookmarks
- [ ] Export timecodes to timeline markers

## Contributing

Ideas, bug reports, and pull requests are welcome.

## License

No license file is included yet. Add one before public release if you want explicit reuse terms.
