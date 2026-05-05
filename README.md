# ScriptViewer — DaVinci Resolve Plugin

Открывает текстовые файлы (сценарии, скрипты) прямо внутри DaVinci Resolve.  
Таймкоды в формате SMPTE `HH:MM:SS:FF` подсвечиваются и при клике перемещают плейхед на таймлайне.

---

## Установка (macOS)

1. Скопируй `ScriptViewer.lua` в папку:

```
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

Быстро открыть через Terminal:
```bash
open "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/"
```

2. Перезапускать Resolve **не нужно** — скрипты подхватываются налету.

3. Запуск:  
   `Workspace → Scripts → Utility → ScriptViewer`

---

## Использование

| Действие | Результат |
|---|---|
| **Open File…** | Выбрать .txt / .fountain / .fdx / .md / .srt |
| Клик на таймкод | Плейхед прыгает на этот момент |
| Спиннер размера шрифта | Меняет размер текста (8–36px) |
| **Clear** | Очистить панель |

---

## Поддерживаемые форматы таймкодов

- `HH:MM:SS:FF` — стандартный SMPTE
- `HH:MM:SS;FF` — drop-frame SMPTE

---

## Поддерживаемые форматы файлов

| Расширение | Описание |
|---|---|
| `.txt` | Простой текст |
| `.fountain` | Fountain screenplay format |
| `.fdx` | Final Draft (читается как текст, теги будут видны) |
| `.srt` | SubRip субтитры |
| `.md` | Markdown |

---

## Разработка в VSCode

Структура файлов:
```
ScriptViewer/
├── ScriptViewer.lua    ← основной файл плагина
└── README.md
```

Рекомендуемые расширения VSCode:
- **sumneko.lua** (Lua Language Server) — синтаксис и автодополнение
- **actboy168.lua-debug** — отладка Lua

Полезные настройки `.vscode/settings.json`:
```json
{
  "Lua.workspace.library": [],
  "Lua.diagnostics.globals": [
    "fu", "ui", "disp", "bmd", "Resolve", "comp", "fusion"
  ],
  "Lua.runtime.version": "Lua 5.1",
  "files.associations": {
    "*.lua": "lua"
  }
}
```

> DaVinci Resolve использует **Lua 5.1** (через Fusion).  
> Глобальные объекты Resolve API (`fu`, `bmd`, `Resolve()`) доступны только внутри Resolve, поэтому отладку удобнее делать через `print()` — вывод идёт в `Workspace → Console`.

---

## Архитектура

```
ScriptViewer.lua
│
├── smpteToFrames(tc, fps)        — конвертация таймкода в номер кадра
├── getProjectFPS()               — берёт FPS текущего проекта из Resolve API
├── jumpToFrame(frames)           — двигает плейхед (SetCurrentTimecode)
│
├── parseLines(raw)               — парсит текст, выделяет таймкоды
├── renderHtml(parsedLines, size) — строит HTML с кликабельными ссылками tc://
│
└── UI (Fusion UIManager)
    ├── BtnOpen         → fu:RequestFile()
    ├── SpinFontSize    → перерендер HTML
    ├── TxtScript       → SetHtml() + AnchorClicked event
    └── BtnClear        → сброс состояния
```

### Как работает клик по таймкоду

Таймкоды рендерятся как HTML-ссылки с кастомной схемой:
```html
<a href="tc://01:23:45:12">01:23:45:12</a>
```
Событие `TxtScript.AnchorClicked` ловит URL, парсит таймкод,  
конвертирует в кадры и вызывает `timeline:SetCurrentTimecode(tc)`.

---

## Возможные доработки

- [ ] Поиск по тексту (Ctrl+F)
- [ ] Автоматическое следование за плейхедом (highlight текущей строки)
- [ ] Полноценный парсер Fountain (форматирование реплик, ремарок)
- [ ] Drag & Drop файлов на окно
- [ ] Закладки на таймкодах
- [ ] Экспорт таймкодов в маркеры таймлайна
