<p align="center">
  <img src="assets/SnipToPath.png" width="96" alt="SnipToPath">
</p>

# SnipToPath

[Русская версия](README.md)

SnipToPath makes screenshots easier to use in terminal-based AI assistants like Codex CLI and Claude Code. It saves a copied image as a temporary PNG and replaces the clipboard image with the local file path.

Use `Win + Shift + S` or `Print Screen` to take a screenshot, or copy an image from a browser or another application. Then paste the path into your terminal with `Ctrl + V` (or `Ctrl + Shift + V`) and write your prompt.

**Note:** This pastes a file path, not the actual image. The assistant needs access to the saved PNG.

## Install

Open Windows PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/alkatrazzjr/SnipToPath/main/install.ps1 | iex
```

Supports Windows 10/11. No administrator privileges or additional runtime dependencies required. Run the same command again to update; your settings are preserved.

## Tray menu

Right-click the tray icon to toggle image processing, open your PNG folder in File Explorer, open Settings, or quit. Double-click the icon to open Settings directly.

## Settings

Configure startup with Windows, light/dark appearance, screenshot folder, automatic cleanup, and the UI language. You can type a full PNG directory path or select one using **Browse**.

**Language:** Automatic (default), Русский, or English. Automatic uses Russian when the Windows UI language is Russian, and English otherwise. Switching language in Settings applies immediately, without restarting.

PNGs are stored in `%TEMP%\SnipToPath` by default. When you copy something new, the previous PNG is scheduled for deletion after a configurable delay (default: **300 seconds**). You can set any whole number from 1 to 604800 seconds (7 days); very short delays may prevent the AI assistant from reading the file. Automatic deletion and cleanup on app startup can each be disabled, and you can also clear temporary PNGs manually in Settings.

SnipToPath does not upload images. It handles all clipboard images, not only screenshots, and leaves ordinary clipboard text unchanged.

## Uninstall

Run in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\SnipToPath\SnipToPath.ps1" -Uninstall
```

Found a bug? Open an [issue](https://github.com/alkatrazzjr/SnipToPath/issues).

[MIT license](LICENSE)
