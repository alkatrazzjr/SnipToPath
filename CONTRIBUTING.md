# Contributing

Thanks for taking an interest in SnipToPath!

1. Search existing issues before creating a new one. For bugs, include Windows version, PowerShell version (`$PSVersionTable.PSVersion`), terminal, and clear reproduction steps (without private screenshots).
2. Make small, focused pull requests. Avoid third-party modules and preserve support for built-in Windows PowerShell 5.1.
3. Run CI syntax/XAML checks; manually test tray behavior, startup toggle, uninstall, and clipboard handling on Windows 10/11.
4. Do not introduce background telemetry, uploads, credential collection, or network requests into the tray app.

By contributing, you agree that your contribution is licensed under the repository's MIT License.
