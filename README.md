# SnipToPath

Когда работаешь с Codex CLI или Claude Code CLI в терминале, скриншоты отправлять неудобно. «Ножницы» кладут картинку в буфер, а консоль далеко не всегда умеет её вставить.

SnipToPath решает это просто: сохраняет картинку в PNG и вместо неё кладёт в буфер **путь к файлу**. Остаётся нажать `Ctrl + V` в терминале. Никаких ручных сохранений и поисков файлов.

Работает на Windows 10/11. Написан на штатном Windows PowerShell 5.1, WPF и WinForms — ничего дополнительно устанавливать не нужно.

## Как пользоваться

Скопируй изображение любым привычным способом:

- `Win + Shift + S` — выделить область экрана.
- `Print Screen` — сделать скриншот или открыть «Ножницы» (зависит от настроек Windows).
- `Копировать изображение` в браузере, мессенджере или другом приложении.

SnipToPath сохранит изображение в PNG и заменит содержимое буфера обмена путём к файлу. Переключись в терминал с Codex CLI (`codex`) или Claude Code CLI (`claude`) и нажми `Ctrl + V`. Дальше можешь написать любой запрос, связанный с изображением: объяснить ошибку, разобрать схему, проверить интерфейс, сравнить два скриншота — или просто попросить агента посмотреть, что на картинке.

**Важно:** вставляется текстовый путь, а не сама картинка. Агенту нужен доступ к локальному PNG, чтобы его открыть. Если `Ctrl + V` в терминале не вставляет текст, попробуй `Ctrl + Shift + V`.

## Установка

Открой **Windows PowerShell** и выполни:

```powershell
irm https://raw.githubusercontent.com/alkatrazzjr/SnipToPath/main/install.ps1 | iex
```

Команда запускает [открытый скрипт установки](install.ps1) из этого репозитория. Если не хочется выполнять скрипт из интернета, сначала посмотри код или скачай [`SnipToPath.ps1`](SnipToPath.ps1) и запусти локально:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SnipToPath.ps1
```

После установки ищи **SnipToPath** в меню «Пуск». Приложение работает в трее (значок может быть спрятан под стрелкой рядом с часами). Администратор не нужен.

Повторная установка обновляет приложение, сохраняя настройки.

## Настройки и очистка

Двойной клик по значку в трее открывает настройки. По правому клику доступны пауза, автозапуск, очистка PNG, выбор темы и выход. Окно поддерживает светлую и тёмную тему Windows.

По умолчанию скриншоты сохраняются в `%TEMP%\SnipToPath`. Чтобы папка не разрасталась:

- **При следующем копировании** старый скриншот ставится в очередь на удаление. Файл удаляется **через 5 минут**, а не сразу: иначе Codex или Claude могут не успеть его открыть. Если агент работает с изображением дольше, эту опцию лучше отключить в настройках.
- **При запуске приложения** оставшиеся PNG SnipToPath удаляются (настройку тоже можно выключить).
- Если нужно, все временные снимки можно удалить вручную через трей.

Оба автоматических способа очистки включены сразу, в том числе для тех, кто обновляется с предыдущей версии. Если просто вставил путь и больше ничего не копировал, последний скрин остаётся до очистки или следующего запуска.

SnipToPath обрабатывает **любые картинки из буфера обмена**, не только снимки из «Ножниц». Например, скопированное из браузера изображение тоже превратится в PNG и путь. Обычный текст программа не меняет.

Сами скриншоты никуда не загружаются. Но они лежат в обычных файлах на диске: не забывай об этом, если на скрине есть личные данные. Когда PNG удалён, старый путь уже не сработает.

## Удаление

В PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\SnipToPath\SnipToPath.ps1" -Uninstall
```

Удалятся приложение, ярлыки, настройки и его временные PNG. Код удаления также есть отдельно в [`uninstall.ps1`](uninstall.ps1).

## Если запускаешь CLI через WSL

Путь из буфера имеет формат Windows (`C:\...`). В WSL он может потребовать преобразования в `/mnt/c/...`; автоматически SnipToPath этого пока не делает.

## Разработка

Основной код — [`SnipToPath.ps1`](SnipToPath.ps1). Используются только компоненты, встроенные в Windows. В [GitHub Actions](.github/workflows/ci.yml) проверяются синтаксис PowerShell, структура XAML и иконка. Это **не замена проверке на живой Windows-сессии**: работу трея и буфера нужно тестировать отдельно.

Предложения и баги — в [Issues](https://github.com/alkatrazzjr/SnipToPath/issues). Лицензия — [MIT](LICENSE).

<details>
<summary>English</summary>

SnipToPath saves clipboard images to temporary PNG files and puts their local file paths back into the clipboard. Paste the path into Codex CLI or Claude Code CLI in your terminal. Made for Windows 10/11 with built-in PowerShell, WPF and WinForms; no extra runtime required.

Clipboard cleanup is enabled by default: when you copy something else, the previous PNG is scheduled for deletion after five minutes. Leftover PNGs are also cleared on app startup. You can turn either option off in settings.

**Note:** This pastes a file path, not an image attachment. The CLI must be able to open the local PNG.

</details>
