# Changelog

## Unreleased

- Новое компактное меню трея на WPF вместо стандартного WinForms ContextMenuStrip.
- Новая иконка приложения и исходники иконки в assets; обновлена документация.
- Настройки, быстрые действия и меню используют общую тему Windows.

- По умолчанию старый временный PNG удаляется через 5 минут после следующего копирования в буфер.
- Очистку при смене буфера можно отключить в настройках и меню трея.
- README переписан и дополнен описанием срока хранения скриншотов.


## 0.1.0 — Initial public release (planned)

- Clipboard image → unique PNG → plain-text file path.
- WPF settings window with Windows light/dark mode and accent color.
- Tray menu: settings, pause, startup, theme, open folder, cleanup, exit.
- User-level installation and Windows Start Menu shortcut.
- Optional cleanup of temporary screenshots on application start.
- No external runtime dependencies.
