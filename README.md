<div align="center">
  <h1>✂️ SnipToPath</h1>
  <p><strong>Скриншот → путь в буфере → Ctrl+V в Codex CLI или Claude Code CLI.</strong></p>
  <p>Лёгкая утилита для Windows 10/11 на встроенных PowerShell, WPF и WinForms. Без сторонних зависимостей и фоновой отправки данных.</p>

  [![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?logo=windows11&logoColor=white)](https://github.com/alkatrazzjr/SnipToPath)
  [![CI](https://github.com/alkatrazzjr/SnipToPath/actions/workflows/ci.yml/badge.svg)](https://github.com/alkatrazzjr/SnipToPath/actions/workflows/ci.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

## Как работает

```text
Win + Shift + S  →  выделить область  →  PNG в %TEMP%\SnipToPath
                                          ↓
                                   путь в буфере
                                          ↓
                                Ctrl + V в терминале
```

**Пример:** После снимка в буфере будет не изображение, а текстовый путь вроде
`"C:\Users\you\AppData\Local\Temp\SnipToPath\snip-20261014-023000-123-a1b2c3.png"`.
Его можно вставить прямо в запрос уже открытого CLI-агента.

> **Важно:** SnipToPath не прикрепляет PNG к сообщению как встроенное изображение. Утилита вставляет **только путь к локальному файлу**; Codex CLI или Claude Code CLI должен иметь доступ к этому пути и самостоятельно открыть изображение. Некоторые терминалы перехватывают `Ctrl+V`: для вставки **текста** попробуйте `Ctrl+Shift+V`.

## Работа с Codex CLI и Claude Code CLI

Здесь речь именно об **интерактивных консольных приложениях**, а не о десктопных интерфейсах Codex или Claude.

| CLI-агент | Команда запуска | Пример запроса после вставки пути |
| --- | --- | --- |
| **OpenAI Codex CLI** | `codex` | `Посмотри скрин по пути "C:\...\snip-....png" и исправь отступы.` |
| **Anthropic Claude Code CLI** | `claude` | `Открой изображение "C:\...\snip-....png" и проверь интерфейс.` |

Название **Claude Code** — официальное; приписка *CLI* в этом README уточняет способ работы через терминал.

**Процесс для обоих агентов:** сделайте `Win + Shift + S`, выделите область, дождитесь преобразования буфера, вставьте путь в текущий запрос через `Ctrl+V` (или `Ctrl+Shift+V`) и отправьте сообщение.

- Вставка пути **не гарантирует**, что агент прочитает изображение: его среда должна иметь доступ к файлу и возможность открывать локальные PNG.
- Для работы из **WSL** Windows-путь вида `C:\...` может потребовать преобразования в `/mnt/c/...`; автоматического преобразования для WSL пока нет.
- При нескольких снимках можно последовательно вставлять пути в один запрос. Файлы сохраняются отдельно, пока вы не очистите папку.

## Установка (Windows PowerShell)

**Одна команда** (запускает открытый скрипт установки из этого репозитория):

```powershell
irm https://raw.githubusercontent.com/alkatrazzjr/SnipToPath/main/install.ps1 | iex
```

Если не хочется запускать удалённый скрипт напрямую: [посмотрите install.ps1](install.ps1), скачайте `SnipToPath.ps1` из репозитория и запустите локально:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SnipToPath.ps1
```

Установка **не требует администратора**: файлы помещаются в `%LOCALAPPDATA%\SnipToPath`, а ярлык создаётся в пользовательском меню «Пуск». После установки ищите `SnipToPath` через поиск Windows или найдите значок в системном трее (он может находиться под стрелкой `^`).

### Обновление

Повторите команду установки. Настройки и выбор автозапуска сохраняются.

### Удаление

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\SnipToPath\SnipToPath.ps1" -Uninstall
```

Или скачайте `uninstall.ps1` и запустите его. Удаляются приложение, ярлыки, его настройки и временные снимки с именами `snip-*.png` в выбранной папке.

## Возможности

| Возможность | Описание |
| --- | --- |
| 📋 Буфер | Сохраняет скопированную картинку как PNG и заменяет её текстовым путём |
| 🖥️ Трей | Двойной клик — настройки, правый — меню с быстрыми действиями |
| 🎨 Темы | Следовать светлой/тёмной теме Windows, либо выбрать вручную |
| ⚡ Автозапуск | Переключается в настройках или контекстном меню |
| 📁 Папка PNG | По умолчанию `%TEMP%\SnipToPath`; можно изменить |
| 🧹 Очистка | При старте удаляет PNG SnipToPath из выбранной папки, опционально |
| ⏸️ Пауза | Отключает перехват картинок без выхода из приложения |
| 🔒 Локально | Не загружает изображения в сеть, не требует аккаунта или администратора |

## Важные детали

- SnipToPath обрабатывает **любое изображение в буфере обмена**, а не только скриншоты от «Ножниц»; исходное содержимое буфера заменяется путём.
- PNG может содержать конфиденциальные данные. Сохраняйте их в локальной папке, к которой есть доступ только у вас; используйте кнопку очистки или автоочистку.
- Автоочистка выполняется **при запуске SnipToPath**, а не буквально при выключении Windows. Если автозапуск выключен, удаление произойдёт при следующем ручном запуске.
- Ссылки на временные файлы перестают работать после их очистки. Не используйте временную папку для долгосрочного хранения.
- Системная тема и акцентный цвет автоматически считываются из настроек Windows. Элементы окна реализованы средствами WPF; это не приложение WinUI 3.

## Для разработчиков

Исходник основного приложения — [`SnipToPath.ps1`](SnipToPath.ps1). Программа рассчитана на **Windows PowerShell 5.1**, STA, системные сборки .NET Framework. Встроенный значок не требует отдельного файла для ручной установки.

В `.github/workflows/ci.yml` — статическая проверка синтаксиса скриптов, XAML и встроенной иконки на Windows runner. Полноценное тестирование поведения буфера и трея требует интерактивной Windows-сессии.

Релиз создаётся по git-тегу `v*` с ZIP и контрольной суммой SHA256 через GitHub Actions. См. [CHANGELOG.md](CHANGELOG.md) и [CONTRIBUTING.md](CONTRIBUTING.md).

## English

SnipToPath is a small Windows utility that saves clipboard images to temporary PNG files and replaces the clipboard content with a pasteable file path. Intended for frequent screenshots in interactive terminal agents such as OpenAI Codex CLI (`codex`) and Anthropic Claude Code CLI (`claude`). It pastes a local PNG file path, not a native image attachment. Built with Windows PowerShell, WPF and WinForms; no third-party dependencies. See the Russian guide above for installation, usage, and privacy notes.

## Лицензия

[MIT](LICENSE) © 2026 alkatrazzjr.

### Выпуск версии (для сопровождающих)

После проверки программы на настоящей Windows-сессии создайте тег `v*`: workflow `release.yml` соберёт ZIP-архив и контрольную сумму. Файл `publish.ps1` сохранён как вспомогательный скрипт первоначальной публикации; обычным пользователям он не нужен.
