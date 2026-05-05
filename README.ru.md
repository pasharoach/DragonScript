# ScriptViewer для DaVinci Resolve

[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![Платформа](https://img.shields.io/badge/Платформа-macOS-111111?logo=apple&logoColor=white)](#установка-macos)
[![Статус](https://img.shields.io/badge/Статус-Активная%20разработка-0A7D32)](#roadmap)
[![Лицензия: MIT](https://img.shields.io/badge/License-MIT-0E8A16.svg)](LICENSE)
[![PRs](https://img.shields.io/badge/PRs-Welcome-1F6FEB)](#contributing)

[English version](README.md)

![Баннер ScriptViewer](assets/banner.svg)

Открывай сценарий прямо внутри Resolve и перемещай playhead по таймкоду одним кликом.

ScriptViewer - легкий Lua-скрипт для DaVinci Resolve/Fusion. Он открывает текстовые документы в отдельной панели, подсвечивает SMPTE-таймкоды и переводит playhead на нужный момент при клике.

## Почему это удобно

- Не нужно переключаться между Resolve и внешним текстовым редактором.
- Кликабельные таймкоды ускоряют навигацию по таймлайну.
- Есть режимы View/Edit для быстрого редактирования текста на месте.
- Save As всегда сохраняет в `.txt`.
- Поддерживаются популярные форматы сценариев и заметок.

## Возможности

- Поддержка файлов: `.txt`, `.fountain`, `.md`, `.srt`, `.fdx`, `.docx`, `.doc`, `.rtf`, `.odt`, `.pages`.
- Распознавание SMPTE-таймкодов:
  - `HH:MM:SS:FF`
  - `HH:MM:SS;FF`
- Переход playhead по клику на таймкод.
- Переключение между режимами View/Edit.
- Настройка размера шрифта (8-36).
- Save As в текстовый файл `.txt`.

## Установка (macOS)

1. Скопируй `ScriptViewer.lua` в папку:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

2. Запусти в DaVinci Resolve:

```text
Workspace -> Scripts -> Utility -> ScriptViewer
```

3. Перезапуск Resolve обычно не требуется.

Быстро открыть папку через Terminal:

```bash
open "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/"
```

## Как использовать

1. Нажми Open... и выбери файл.
2. Кликни по таймкоду в тексте для перехода playhead.
3. Нажми Edit для правок и View для возврата к кликабельному режиму.
4. Нажми Save As... чтобы сохранить текущий текст в `.txt`.

## Для кого

- Монтажеры, работающие со сценарием и таймкодами.
- Режиссеры и ассистенты, проверяющие заметки по монтажу.
- Script-supervisor workflow внутри одной программы.

## Технически

- Язык: Lua 5.1 (Fusion scripting).
- UI: Fusion UIManager.
- Интеграция: Resolve API (`Resolve()`, timeline navigation).

## Roadmap

- [ ] Поиск по тексту
- [ ] Поддержка drag and drop
- [ ] Закладки таймкодов
- [ ] Экспорт таймкодов в маркеры таймлайна

## Contributing

Идеи, issue и pull request приветствуются.

## License

Проект распространяется по лицензии MIT. См. файл [LICENSE](LICENSE).
