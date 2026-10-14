# SnipToPath — Snipping Tool clipboard images -> temporary PNG -> pasteable file path.
# Windows 10/11, built-in Windows PowerShell 5.1 + Windows Forms; no external software.
# Run this file without arguments to install/update, create a Start Menu shortcut, and launch.
# Run the installed file with -Uninstall for complete removal.
[CmdletBinding()]
param(
    [switch]$Tray,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$appDir = Join-Path $env:LOCALAPPDATA 'SnipToPath'
$installedScript = Join-Path $appDir 'SnipToPath.ps1'
$settingsPath = Join-Path $appDir 'settings.json'
$iconPath = Join-Path $appDir 'SnipToPath.ico'
$launcherPath = Join-Path $appDir 'SnipToPath.vbs'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'SnipToPath.lnk'
$menuLink = Join-Path ([Environment]::GetFolderPath('Programs')) 'SnipToPath.lnk'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'
$script:isExiting = $false

function Get-Defaults {
    return [ordered]@{
        Enabled        = $true
        StartCleanup   = $true
        QuotedPaths    = $true
        ThemeMode      = 'System'
        ScreenshotDir  = (Join-Path $env:TEMP 'SnipToPath')
    }
}

function Load-Settings {
    $script:config = Get-Defaults
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $previous = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($key in @('Enabled', 'StartCleanup', 'QuotedPaths', 'ScreenshotDir', 'ThemeMode')) {
                if ($null -ne $previous.PSObject.Properties[$key] -and $null -ne $previous.$key) {
                    $script:config[$key] = $previous.$key
                }
            }
        }
        catch { Write-Warning 'Could not read settings.json; using defaults.' }
    }
    if ([string]$script:config.ThemeMode -notin @('System','Light','Dark')) { $script:config.ThemeMode = 'System' }
    if ([string]::IsNullOrWhiteSpace([string]$script:config.ScreenshotDir)) {
        $script:config.ScreenshotDir = Join-Path $env:TEMP 'SnipToPath'
    }
}

function Save-Settings {
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    $tempPath = Join-Path $appDir 'settings.json.tmp'
    $script:config | ConvertTo-Json | Set-Content -LiteralPath $tempPath -Encoding UTF8
    Move-Item -LiteralPath $tempPath -Destination $settingsPath -Force
}

function Write-Log([string]$message) {
    try {
        Add-Content -LiteralPath (Join-Path $appDir 'errors.log') -Value ("{0} {1}" -f (Get-Date -Format 'o'), $message) -ErrorAction SilentlyContinue
    }
    catch {}
}

function Remove-OwnScreenshots([string]$folder) {
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) { return 0 }
    $count = 0
    Get-ChildItem -LiteralPath $folder -Filter 'snip-*.png' -File -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $count = $count + 1 }
        catch { Write-Log $_.Exception.Message }
    }
    return $count
}

function Set-Startup([bool]$enable) {
    if ($enable) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupLink)
        $shortcut.TargetPath = $wscriptExe
        $shortcut.Arguments = ('"{0}"' -f $launcherPath)
        $shortcut.WorkingDirectory = $appDir
        $shortcut.Description = 'SnipToPath: clipboard screenshots to file paths'
        if (Test-Path -LiteralPath $iconPath) { $shortcut.IconLocation = $iconPath }
        $shortcut.Save()
    }
    elseif (Test-Path -LiteralPath $startupLink) {
        Remove-Item -LiteralPath $startupLink -Force
    }
}

function Stop-InstalledInstances {
    # Only terminate PowerShell processes running this exact installed script with -Tray/-Watch.
    # Needed once when updating the previous background-only version.
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessId -ne $PID -and $_.CommandLine -and
            $_.CommandLine.IndexOf($installedScript, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.CommandLine -match '(?i)(?:^|\s)-(?:Tray|Watch)(?:\s|$)'
        } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

if ($Uninstall) {
    Stop-InstalledInstances
    Load-Settings
    foreach ($link in @($startupLink, $menuLink)) {
        if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
    }
    $removed = Remove-OwnScreenshots ([string]$script:config.ScreenshotDir)
    # The old version used this directory regardless of configuration.
    $defaultFolder = Join-Path $env:TEMP 'SnipToPath'
    if (-not [string]::Equals($defaultFolder, [string]$script:config.ScreenshotDir, [StringComparison]::OrdinalIgnoreCase)) {
        $null = Remove-OwnScreenshots $defaultFolder
    }
    if (Test-Path -LiteralPath $appDir) { Remove-Item -LiteralPath $appDir -Recurse -Force }
    Write-Host 'SnipToPath removed: tray, shortcuts, settings, and its temporary PNGs.'
    return
}

if (-not $Tray) {
    # Installer/updater (run once; can also update the earlier version).
    $alreadyInstalled = Test-Path -LiteralPath $installedScript
    $previousStartup = Test-Path -LiteralPath $startupLink
    New-Item -Path $appDir -ItemType Directory -Force | Out-Null
    Stop-InstalledInstances

    $source = (Resolve-Path -LiteralPath $PSCommandPath).Path
    if (-not [string]::Equals($source, $installedScript, [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $source -Destination $installedScript -Force
    }

    # Embedded icon data. Generated at build time; Windows does not need PIL or Python.
    $ico = @'
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
rkJggg==
'@
    [IO.File]::WriteAllBytes($iconPath, [Convert]::FromBase64String(($ico -replace '\s','')))

    $exeEsc = $psExe.Replace('"', '""')
    $scriptEsc = $installedScript.Replace('"', '""')
    $vbs = 'Set WshShell = CreateObject("WScript.Shell")' + "`r`n" +
        ('WshShell.Run """{0}"" -NoProfile -NoLogo -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{1}"" -Tray", 0, False' -f $exeEsc, $scriptEsc) + "`r`n"
    [IO.File]::WriteAllText($launcherPath, $vbs, [Text.Encoding]::Unicode)

    Load-Settings
    Save-Settings

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($menuLink)
    $shortcut.TargetPath = $wscriptExe
    $shortcut.Arguments = ('"{0}"' -f $launcherPath)
    $shortcut.WorkingDirectory = $appDir
    $shortcut.Description = 'Screenshot paths for Codex CLI and Claude Code'
    $shortcut.IconLocation = $iconPath
    $shortcut.Save()

    # First install: autostart ON. Update: preserve previous ON/OFF choice.
    if (-not $alreadyInstalled -or $previousStartup) { Set-Startup $true }

    Start-Process -FilePath $wscriptExe -ArgumentList ('"{0}"' -f $launcherPath)
    Write-Host 'SnipToPath installed and launched.' -ForegroundColor Green
    Write-Host 'Search Windows for: SnipToPath'
    Write-Host 'Right-click its tray icon to open Settings, pause, disable autostart, or Exit.'
    Write-Host 'Win + Shift + S -> wait a moment -> Ctrl + V in Codex/Claude.'
    Write-Host ('Remove: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -Uninstall' -f $installedScript)
    return
}

# Tray mode, launched by Windows Script Host (no visible console).
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'SnipToPath needs an STA PowerShell process.'
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace SnipNative -Name ClipboardCounter -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern uint GetClipboardSequenceNumber();
'@

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace SnipUI {
    public static class Native {
        [DllImport("dwmapi.dll", PreserveSig = true)]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    }
    public sealed class MenuColors : ProfessionalColorTable {
        public Color Canvas { get; set; }
        public Color Hover { get; set; }
        public Color Edge { get; set; }
        public override Color ToolStripDropDownBackground { get { return Canvas; } }
        public override Color ImageMarginGradientBegin { get { return Canvas; } }
        public override Color ImageMarginGradientMiddle { get { return Canvas; } }
        public override Color ImageMarginGradientEnd { get { return Canvas; } }
        public override Color MenuItemSelected { get { return Hover; } }
        public override Color MenuItemSelectedGradientBegin { get { return Hover; } }
        public override Color MenuItemSelectedGradientEnd { get { return Hover; } }
        public override Color MenuItemPressedGradientBegin { get { return Hover; } }
        public override Color MenuItemPressedGradientMiddle { get { return Hover; } }
        public override Color MenuItemPressedGradientEnd { get { return Hover; } }
        public override Color MenuItemBorder { get { return Edge; } }
        public override Color MenuBorder { get { return Edge; } }
        public override Color SeparatorDark { get { return Edge; } }
        public override Color SeparatorLight { get { return Canvas; } }
        public override Color CheckBackground { get { return Hover; } }
        public override Color CheckSelectedBackground { get { return Hover; } }
        public override Color CheckPressedBackground { get { return Hover; } }
    }
}
'@ -ReferencedAssemblies 'System.Drawing', 'System.Windows.Forms'

$createdNew = $false
$singleInstance = [Threading.Mutex]::new($true, 'Local\SnipToPathTray-v2', [ref]$createdNew)
if (-not $createdNew) {
    $singleInstance.Dispose()
    try {
        $notifyExisting = [Threading.EventWaitHandle]::OpenExisting('Local\SnipToPathOpenSettings-v2')
        $null = $notifyExisting.Set()
        $notifyExisting.Dispose()
    }
    catch {}
    return
}

$script:settingsSignal = $null
$script:notify = $null
$script:tick = $null
$script:settingsForm = $null
$script:context = $null
$script:icon = $null

try {
    $script:settingsSignal = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, 'Local\SnipToPathOpenSettings-v2')
    [System.Windows.Forms.Application]::EnableVisualStyles()
    Load-Settings
    $script:shotFolder = [string]$script:config.ScreenshotDir
    New-Item -ItemType Directory -Path $script:shotFolder -Force | Out-Null
    if ($script:config.StartCleanup) { $null = Remove-OwnScreenshots $script:shotFolder }
    $script:lastSeq = [SnipNative.ClipboardCounter]::GetClipboardSequenceNumber()

    if (Test-Path -LiteralPath $iconPath) {
        $script:icon = [System.Drawing.Icon]::new($iconPath)
    } else {
        $script:icon = [System.Drawing.SystemIcons]::Application
    }

    $script:context = New-Object System.Windows.Forms.ApplicationContext
    $script:notify = New-Object System.Windows.Forms.NotifyIcon
    $script:notify.Icon = $script:icon
    $script:notify.Text = 'SnipToPath — скриншоты в пути'

    $script:menu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:menu.ShowImageMargin = $false
    $script:menu.ShowCheckMargin = $true
    $script:menu.Font = [System.Drawing.Font]::new('Segoe UI', 9.5)
    $script:menu.Padding = [System.Windows.Forms.Padding]::new(5)
    $script:menuSettings = [System.Windows.Forms.ToolStripMenuItem]::new('Настройки...')
    $script:menuPause = [System.Windows.Forms.ToolStripMenuItem]::new('Обрабатывать скриншоты')
    $script:menuPause.CheckOnClick = $true
    $script:menuStartup = [System.Windows.Forms.ToolStripMenuItem]::new('Запускать с Windows')
    $script:menuStartup.CheckOnClick = $true
    $script:menuTheme = [System.Windows.Forms.ToolStripMenuItem]::new('Тема приложения')
    $script:menuThemeSystem = [System.Windows.Forms.ToolStripMenuItem]::new('Как в Windows')
    $script:menuThemeLight = [System.Windows.Forms.ToolStripMenuItem]::new('Светлая')
    $script:menuThemeDark = [System.Windows.Forms.ToolStripMenuItem]::new('Тёмная')
    foreach ($themeItem in @($script:menuThemeSystem, $script:menuThemeLight, $script:menuThemeDark)) {
        $null = $script:menuTheme.DropDownItems.Add($themeItem)
    }
    $script:menuFolder = [System.Windows.Forms.ToolStripMenuItem]::new('Открыть папку PNG')
    $script:menuClear = [System.Windows.Forms.ToolStripMenuItem]::new('Удалить временные PNG')
    $script:menuExit = [System.Windows.Forms.ToolStripMenuItem]::new('Выход')

    foreach ($item in @($script:menuSettings, $script:menuPause, $script:menuStartup, $script:menuTheme)) {
        $null = $script:menu.Items.Add($item)
    }
    $null = $script:menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    foreach ($item in @($script:menuFolder, $script:menuClear)) { $null = $script:menu.Items.Add($item) }
    $null = $script:menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = $script:menu.Items.Add($script:menuExit)
    $script:notify.ContextMenuStrip = $script:menu

    function Get-ThemeState {
        $mode = [string]$script:config.ThemeMode
        $appsLight = 1
        try {
            $reg = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop
            if ($null -ne $reg.AppsUseLightTheme) { $appsLight = [int]$reg.AppsUseLightTheme }
        } catch {}
        $isDark = if ($mode -eq 'Dark') { $true } elseif ($mode -eq 'Light') { $false } else { $appsLight -eq 0 }
        $accent = '#0067C0'
        try {
            $colors = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction Stop
            if ($null -ne $colors.AccentColor) {
                $bytes = [BitConverter]::GetBytes([int]$colors.AccentColor)
                $r = [int]$bytes[0]; $g = [int]$bytes[1]; $b = [int]$bytes[2]
                # Ignore implausibly dark/high-contrast accents for legibility.
                if (($r + $g + $b) -gt 95 -and ($r + $g + $b) -lt 680) {
                    $accent = '#{0:X2}{1:X2}{2:X2}' -f $r, $g, $b
                }
            }
        } catch {}
        return @{ IsDark = $isDark; Accent = $accent; Signature = ('{0}|{1}' -f $isDark, $accent) }
    }

    function Apply-Theme {
        $state = Get-ThemeState
        $script:themeSignature = $state.Signature
        if ($state.IsDark) {
            $colors = @{
                PageBrush='#17181A'; CardBrush='#242529'; AltBrush='#303136'
                TextBrush='#F7F7F7'; SubtleBrush='#B6B9C3'; LineBrush='#414349'
                HoverBrush='#373A40'; AccentSubtleBrush='#283B4D'; OffBrush='#60646D'
            }
        } else {
            $colors = @{
                PageBrush='#F3F3F3'; CardBrush='#FFFFFF'; AltBrush='#F9F9FA'
                TextBrush='#1C1C1E'; SubtleBrush='#60636B'; LineBrush='#E2E3E8'
                HoverBrush='#E9EAEE'; AccentSubtleBrush='#E6F0FA'; OffBrush='#898C95'
            }
        }
        $colors['AccentBrush'] = $state.Accent
        $colors['AccentHoverBrush'] = if ($state.IsDark) { '#327EBC' } else { '#00549C' }
        $colors['AccentTextBrush'] = '#FFFFFF'
        $colors['SwitchThumbBrush'] = '#FFFFFF'
        $colors['WindowStrokeBrush'] = if ($state.IsDark) { '#4B4D54' } else { '#E5E6EB' }
        if ($script:settingsForm) {
            foreach ($entry in $colors.GetEnumerator()) {
                $script:settingsForm.Resources[$entry.Key] = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value))
            }
            try {
                $helper = [System.Windows.Interop.WindowInteropHelper]::new($script:settingsForm)
                $hwnd = $helper.EnsureHandle()
                $darkVal = if ($state.IsDark) { 1 } else { 0 }
                $roundVal = 2
                $null = [SnipUI.Native]::DwmSetWindowAttribute($hwnd, 20, [ref]$darkVal, 4)
                $null = [SnipUI.Native]::DwmSetWindowAttribute($hwnd, 33, [ref]$roundVal, 4)
            } catch {}
        }
        if ($script:menu) {
            $canvas = [System.Drawing.ColorTranslator]::FromHtml($colors['CardBrush'])
            $hover = [System.Drawing.ColorTranslator]::FromHtml($colors['HoverBrush'])
            $line = [System.Drawing.ColorTranslator]::FromHtml($colors['LineBrush'])
            $fg = [System.Drawing.ColorTranslator]::FromHtml($colors['TextBrush'])
            $table = [SnipUI.MenuColors]::new()
            $table.Canvas = $canvas; $table.Hover = $hover; $table.Edge = $line
            $script:menu.Renderer = [System.Windows.Forms.ToolStripProfessionalRenderer]::new($table)
            $script:menu.BackColor = $canvas
            $script:menu.ForeColor = $fg
            foreach ($item in $script:menu.Items) {
                $item.ForeColor = $fg; $item.BackColor = $canvas
            }
            foreach ($item in $script:menuTheme.DropDownItems) {
                $item.ForeColor = $fg; $item.BackColor = $canvas
            }
            $script:menuTheme.DropDown.BackColor = $canvas
            $script:menuTheme.DropDown.ForeColor = $fg
        }
    }

    function Sync-Menus {
        $script:menuPause.Checked = [bool]$script:config.Enabled
        $script:menuStartup.Checked = Test-Path -LiteralPath $startupLink
        $script:menuThemeSystem.Checked = [string]$script:config.ThemeMode -eq 'System'
        $script:menuThemeLight.Checked = [string]$script:config.ThemeMode -eq 'Light'
        $script:menuThemeDark.Checked = [string]$script:config.ThemeMode -eq 'Dark'
        $script:notify.Text = if ($script:config.Enabled) { 'SnipToPath - работает' } else { 'SnipToPath - пауза' }
        if ($script:settingsForm) {
            $script:ui.StatusName.Text = if ($script:config.Enabled) { 'Работает' } else { 'На паузе' }
            $script:ui.StatusHint.Text = if ($script:config.Enabled) {
                'Скопируйте скриншот и вставьте путь в консоль.'
            } else { 'Отслеживание буфера обмена приостановлено.' }
        }
    }

    function Set-ThemeMode([string]$mode) {
        if ($mode -notin @('System','Light','Dark')) { return }
        $script:config.ThemeMode = $mode
        Save-Settings
        Sync-Menus
        Apply-Theme
        if ($script:settingsForm) {
            $newIndex = switch ($mode) { 'Light' {1} 'Dark' {2} default {0} }
            if ($script:ui.ThemeChoice.SelectedIndex -ne $newIndex) {
                $script:ui.ThemeChoice.SelectedIndex = $newIndex
            }
        }
    }

    function New-SettingsWindow {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SnipToPath — Настройки" Width="650" Height="742" MinWidth="600" MinHeight="620"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource PageBrush}"
        FontFamily="Segoe UI" FontSize="13" ShowInTaskbar="True">
    <Window.Resources>
        <SolidColorBrush x:Key="PageBrush" Color="#F3F3F3"/>
        <SolidColorBrush x:Key="CardBrush" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="AltBrush" Color="#F9F9FA"/>
        <SolidColorBrush x:Key="TextBrush" Color="#1C1C1E"/>
        <SolidColorBrush x:Key="SubtleBrush" Color="#60636B"/>
        <SolidColorBrush x:Key="LineBrush" Color="#E2E3E8"/>
        <SolidColorBrush x:Key="HoverBrush" Color="#E9EAEE"/>
        <SolidColorBrush x:Key="AccentBrush" Color="#0067C0"/>
        <SolidColorBrush x:Key="AccentHoverBrush" Color="#00549C"/>
        <SolidColorBrush x:Key="AccentTextBrush" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="AccentSubtleBrush" Color="#E6F0FA"/>
        <SolidColorBrush x:Key="OffBrush" Color="#898C95"/>
        <SolidColorBrush x:Key="SwitchThumbBrush" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="WindowStrokeBrush" Color="#E5E6EB"/>
        <Style TargetType="TextBlock"><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/></Style>
        <Style x:Key="Hint" TargetType="TextBlock"><Setter Property="Foreground" Value="{DynamicResource SubtleBrush}"/><Setter Property="FontSize" Value="12"/><Setter Property="TextWrapping" Value="Wrap"/></Style>
        <Style x:Key="Section" TargetType="TextBlock"><Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Margin" Value="0,0,0,12"/></Style>
        <Style x:Key="Card" TargetType="Border"><Setter Property="Background" Value="{DynamicResource CardBrush}"/><Setter Property="BorderBrush" Value="{DynamicResource LineBrush}"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="11"/><Setter Property="Padding" Value="18,15"/><Setter Property="Margin" Value="0,0,0,18"/></Style>
        <Style x:Key="Switch" TargetType="ToggleButton">
            <Setter Property="Width" Value="46"/><Setter Property="Height" Value="25"/><Setter Property="Focusable" Value="True"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ToggleButton">
                <Border x:Name="Track" Width="44" Height="24" CornerRadius="12" Background="{DynamicResource OffBrush}">
                    <Ellipse x:Name="Thumb" Width="16" Height="16" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="4,0" Fill="{DynamicResource SwitchThumbBrush}"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsChecked" Value="True"><Setter TargetName="Track" Property="Background" Value="{DynamicResource AccentBrush}"/><Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/></Trigger>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Thumb" Property="Width" Value="18"/><Setter TargetName="Thumb" Property="Height" Value="18"/></Trigger>
                    <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="SoftButton" TargetType="Button">
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Setter Property="Background" Value="{DynamicResource AltBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource LineBrush}"/><Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="13"/><Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,8"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="Chrome" CornerRadius="8" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Chrome" Property="Background" Value="{DynamicResource HoverBrush}"/></Trigger>
                    <Trigger Property="IsPressed" Value="True"><Setter TargetName="Chrome" Property="Opacity" Value="0.75"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource SoftButton}">
            <Setter Property="Foreground" Value="{DynamicResource AccentTextBrush}"/><Setter Property="Background" Value="{DynamicResource AccentBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="Chrome" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Chrome" Property="Background" Value="{DynamicResource AccentHoverBrush}"/></Trigger>
                    <Trigger Property="IsPressed" Value="True"><Setter TargetName="Chrome" Property="Opacity" Value="0.78"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="ModernCombo" TargetType="ComboBox">
            <Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="13"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Setter Property="Background" Value="{DynamicResource AltBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource LineBrush}"/><Setter Property="Padding" Value="12,7"/>
            <Setter Property="MinWidth" Value="185"/><Setter Property="Height" Value="36"/>
        </Style>
    </Window.Resources>
    <DockPanel LastChildFill="True">
        <Border DockPanel.Dock="Bottom" Background="{DynamicResource CardBrush}" BorderBrush="{DynamicResource LineBrush}" BorderThickness="0,1,0,0" Padding="24,14">
            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <Button x:Name="ClearButton" Grid.Column="0" Content="Очистить PNG" Height="38" Style="{StaticResource SoftButton}"/>
                <Button x:Name="CloseButton" Grid.Column="2" Content="Готово" Width="116" Height="38" Style="{StaticResource PrimaryButton}"/>
            </Grid>
        </Border>
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel Margin="28,24,28,12">
                <Grid Margin="0,0,0,16">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel>
                        <TextBlock Text="SnipToPath" FontSize="27" FontWeight="SemiBold"/>
                        <TextBlock Text="Скриншоты без лишних движений" Style="{StaticResource Hint}" Margin="0,4,0,0"/>
                    </StackPanel>
                    <Border Grid.Column="1" VerticalAlignment="Center" Background="{DynamicResource AccentSubtleBrush}" CornerRadius="13" Padding="12,6">
                        <StackPanel Orientation="Horizontal"><Ellipse Width="7" Height="7" Fill="{DynamicResource AccentBrush}" Margin="0,0,7,0" VerticalAlignment="Center"/><TextBlock x:Name="StatusName" Text="Работает" Foreground="{DynamicResource AccentBrush}" FontWeight="SemiBold" FontSize="12"/></StackPanel>
                    </Border>
                </Grid>
                <Border Style="{StaticResource Card}" Background="{DynamicResource AccentSubtleBrush}" BorderThickness="0" Padding="16,14">
                    <StackPanel>
                        <TextBlock FontWeight="SemiBold" FontSize="14" Text="Win + Shift + S   →   Ctrl + V"/>
                        <TextBlock x:Name="StatusHint" Text="Скопируйте скриншот и вставьте путь в консоль." Style="{StaticResource Hint}" Margin="0,5,0,0"/>
                    </StackPanel>
                </Border>
                <TextBlock Style="{StaticResource Section}" Text="Захват"/>
                <Border Style="{StaticResource Card}"><StackPanel>
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <StackPanel Margin="0,0,16,0"><TextBlock Text="Автоматически копировать путь" FontWeight="SemiBold"/><TextBlock Text="Сохранять PNG, а в буфер помещать путь к файлу" Style="{StaticResource Hint}" Margin="0,4,0,0"/></StackPanel>
                        <ToggleButton x:Name="EnabledSwitch" Grid.Column="1" VerticalAlignment="Center" Style="{StaticResource Switch}"/>
                    </Grid>
                    <Border Background="{DynamicResource LineBrush}" Height="1" Margin="0,15"/>
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <StackPanel Margin="0,0,16,0"><TextBlock Text="Путь в кавычках" FontWeight="SemiBold"/><TextBlock Text="Удобнее для путей с пробелами" Style="{StaticResource Hint}" Margin="0,4,0,0"/></StackPanel>
                        <ToggleButton x:Name="QuotesSwitch" Grid.Column="1" VerticalAlignment="Center" Style="{StaticResource Switch}"/>
                    </Grid>
                </StackPanel></Border>
                <TextBlock Style="{StaticResource Section}" Text="Система"/>
                <Border Style="{StaticResource Card}"><StackPanel>
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <StackPanel Margin="0,0,16,0"><TextBlock Text="Запускать вместе с Windows" FontWeight="SemiBold"/><TextBlock Text="Приложение будет работать в трее" Style="{StaticResource Hint}" Margin="0,4,0,0"/></StackPanel>
                        <ToggleButton x:Name="StartupSwitch" Grid.Column="1" VerticalAlignment="Center" Style="{StaticResource Switch}"/>
                    </Grid>
                    <Border Background="{DynamicResource LineBrush}" Height="1" Margin="0,15"/>
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <StackPanel Margin="0,0,16,0"><TextBlock Text="Очищать PNG при запуске" FontWeight="SemiBold"/><TextBlock Text="Удаляются только скриншоты SnipToPath" Style="{StaticResource Hint}" Margin="0,4,0,0"/></StackPanel>
                        <ToggleButton x:Name="CleanupSwitch" Grid.Column="1" VerticalAlignment="Center" Style="{StaticResource Switch}"/>
                    </Grid>
                </StackPanel></Border>
                <TextBlock Style="{StaticResource Section}" Text="Хранилище"/>
                <Border Style="{StaticResource Card}"><StackPanel>
                    <TextBlock Text="Папка временных PNG" FontWeight="SemiBold" Margin="0,0,0,9"/>
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{DynamicResource AltBrush}" BorderBrush="{DynamicResource LineBrush}" BorderThickness="1" CornerRadius="8" Padding="11,9" Margin="0,0,8,0">
                            <TextBlock x:Name="FolderText" TextTrimming="CharacterEllipsis" FontSize="12" VerticalAlignment="Center"/>
                        </Border>
                        <Button x:Name="FolderButton" Grid.Column="1" Content="Изменить" Style="{StaticResource SoftButton}"/>
                    </Grid>
                </StackPanel></Border>
                <TextBlock Style="{StaticResource Section}" Text="Внешний вид"/>
                <Border Style="{StaticResource Card}"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel Margin="0,0,16,0"><TextBlock Text="Тема приложения" FontWeight="SemiBold"/><TextBlock Text="Системная следует настройкам Windows" Style="{StaticResource Hint}" Margin="0,4,0,0"/></StackPanel>
                    <ComboBox x:Name="ThemeChoice" Grid.Column="1" VerticalAlignment="Center" Style="{StaticResource ModernCombo}"><ComboBoxItem Content="Как в Windows"/><ComboBoxItem Content="Светлая"/><ComboBoxItem Content="Тёмная"/></ComboBox>
                </Grid></Border>
                <TextBlock Text="Изменения сохраняются автоматически. Приложение продолжает работу в трее после закрытия окна." Style="{StaticResource Hint}" Margin="2,0,8,12"/>
            </StackPanel>
        </ScrollViewer>
    </DockPanel>
</Window>
'@
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $window.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($script:icon.Handle, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
        $script:settingsForm = $window
        $script:ui = @{}
        foreach ($name in @('StatusName','StatusHint','EnabledSwitch','QuotesSwitch','StartupSwitch','CleanupSwitch','FolderText','FolderButton','ThemeChoice','ClearButton','CloseButton')) {
            $script:ui[$name] = $window.FindName($name)
            if (-not $script:ui[$name]) { throw ('Элемент интерфейса не найден: ' + $name) }
        }
        $script:ui.EnabledSwitch.IsChecked = [bool]$script:config.Enabled
        $script:ui.QuotesSwitch.IsChecked = [bool]$script:config.QuotedPaths
        $script:ui.StartupSwitch.IsChecked = Test-Path -LiteralPath $startupLink
        $script:ui.CleanupSwitch.IsChecked = [bool]$script:config.StartCleanup
        $script:ui.FolderText.Text = [string]$script:config.ScreenshotDir
        $script:ui.ThemeChoice.SelectedIndex = switch ([string]$script:config.ThemeMode) { 'Light' {1} 'Dark' {2} default {0} }

        $script:ui.EnabledSwitch.Add_Click({
            $script:config.Enabled = [bool]$script:ui.EnabledSwitch.IsChecked
            Save-Settings; Sync-Menus
        })
        $script:ui.QuotesSwitch.Add_Click({
            $script:config.QuotedPaths = [bool]$script:ui.QuotesSwitch.IsChecked
            Save-Settings
        })
        $script:ui.StartupSwitch.Add_Click({
            try { Set-Startup ([bool]$script:ui.StartupSwitch.IsChecked) }
            catch {
                $script:ui.StartupSwitch.IsChecked = Test-Path -LiteralPath $startupLink
                [System.Windows.MessageBox]::Show($_.Exception.Message, 'SnipToPath', 'OK', 'Error') | Out-Null
            }
            Sync-Menus
        })
        $script:ui.CleanupSwitch.Add_Click({
            $script:config.StartCleanup = [bool]$script:ui.CleanupSwitch.IsChecked
            Save-Settings
        })
        $script:ui.ThemeChoice.Add_SelectionChanged({
            $mode = @('System','Light','Dark')[[int]$script:ui.ThemeChoice.SelectedIndex]
            if ($mode) { Set-ThemeMode $mode }
        })
        $script:ui.FolderButton.Add_Click({
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            try {
                $dialog.Description = 'Папка для временных PNG'
                if (Test-Path -LiteralPath $script:shotFolder -PathType Container) { $dialog.SelectedPath = $script:shotFolder }
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $folder = $dialog.SelectedPath
                    New-Item -ItemType Directory -Path $folder -Force | Out-Null
                    $script:config.ScreenshotDir = $folder
                    $script:shotFolder = $folder
                    $script:ui.FolderText.Text = $folder
                    Save-Settings
                }
            } catch {
                [System.Windows.MessageBox]::Show($_.Exception.Message, 'SnipToPath', 'OK', 'Error') | Out-Null
            } finally { $dialog.Dispose() }
        })
        $script:ui.ClearButton.Add_Click({
            $deleted = Remove-OwnScreenshots $script:shotFolder
            [System.Windows.MessageBox]::Show(('Удалено временных PNG: {0}' -f $deleted), 'SnipToPath', 'OK', 'Information') | Out-Null
        })
        $script:ui.CloseButton.Add_Click({ $script:settingsForm.Hide() })
        $window.Add_Closing({ param($sender, $e)
            if (-not $script:isExiting) { $e.Cancel = $true; $sender.Hide() }
        })
        Apply-Theme
        Sync-Menus
    }

    function Show-Settings {
        if ($null -eq $script:settingsForm) { New-SettingsWindow }
        $script:ui.StartupSwitch.IsChecked = Test-Path -LiteralPath $startupLink
        $script:settingsForm.Show()
        $script:settingsForm.WindowState = [System.Windows.WindowState]::Normal
        $null = $script:settingsForm.Activate()
    }

    function Exit-SnipToPath {
        $script:isExiting = $true
        $script:tick.Stop()
        $script:notify.Visible = $false
        if ($script:settingsForm) {
            $script:settingsForm.Close()
        }
        $script:context.ExitThread()
    }

    $script:menuSettings.Add_Click({ Show-Settings })
    $script:menuThemeSystem.Add_Click({ Set-ThemeMode 'System' })
    $script:menuThemeLight.Add_Click({ Set-ThemeMode 'Light' })
    $script:menuThemeDark.Add_Click({ Set-ThemeMode 'Dark' })
    $script:notify.Add_DoubleClick({ Show-Settings })
    $script:menuPause.Add_Click({
        $script:config.Enabled = [bool]$script:menuPause.Checked
        Save-Settings
        Sync-Menus
    })
    $script:menuStartup.Add_Click({
        try { Set-Startup ([bool]$script:menuStartup.Checked) }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'SnipToPath', 'OK', 'Error') | Out-Null }
        Sync-Menus
    })
    $script:menuFolder.Add_Click({
        New-Item -ItemType Directory -Path $script:shotFolder -Force | Out-Null
        Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $script:shotFolder)
    })
    $script:menuClear.Add_Click({
        $deleted = Remove-OwnScreenshots $script:shotFolder
        $script:notify.ShowBalloonTip(1500, 'SnipToPath', ("Удалено PNG: {0}" -f $deleted), [System.Windows.Forms.ToolTipIcon]::Info)
    })
    $script:menuExit.Add_Click({ Exit-SnipToPath })
    Sync-Menus
    Apply-Theme
    $script:themePoll = 0

    $script:tick = New-Object System.Windows.Forms.Timer
    $script:tick.Interval = 200
    $script:tick.Add_Tick({
        try {
            if ($script:settingsSignal.WaitOne(0)) { Show-Settings }
            $script:themePoll++
            if ($script:themePoll -ge 10) {
                $script:themePoll = 0
                if ((Get-ThemeState).Signature -ne $script:themeSignature) { Apply-Theme }
            }
            $currentSeq = [SnipNative.ClipboardCounter]::GetClipboardSequenceNumber()
            if (-not $script:config.Enabled) {
                $script:lastSeq = $currentSeq
                return
            }
            if ($currentSeq -eq $script:lastSeq) { return }
            if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
                $script:lastSeq = $currentSeq
                return
            }
            $image = [System.Windows.Forms.Clipboard]::GetImage()
            if ($null -eq $image) { return }

            New-Item -ItemType Directory -Path $script:shotFolder -Force | Out-Null
            $filename = 'snip-{0}-{1}.png' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([Guid]::NewGuid().ToString('N').Substring(0, 6))
            $filePath = Join-Path $script:shotFolder $filename
            try { $image.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png) }
            finally { $image.Dispose() }

            $clipboardText = if ($script:config.QuotedPaths) { '"' + $filePath + '"' } else { $filePath }
            # Clipboard can be locked by Snipping Tool for a short moment.
            [System.Windows.Forms.Clipboard]::SetText($clipboardText)
            $script:lastSeq = [SnipNative.ClipboardCounter]::GetClipboardSequenceNumber()
        }
        catch [System.Runtime.InteropServices.ExternalException] {
            # Do not mark the clipboard as handled; retry on the next tick.
        }
        catch {
            Write-Log ($_.ToString())
            $script:lastSeq = [SnipNative.ClipboardCounter]::GetClipboardSequenceNumber()
        }
    })
    $script:notify.Visible = $true
    $script:tick.Start()
    [System.Windows.Forms.Application]::Run($script:context)
}
catch {
    Write-Log ($_.ToString())
    try { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'SnipToPath', 'OK', 'Error') | Out-Null } catch {}
}
finally {
    if ($script:tick) { $script:tick.Dispose() }
    if ($script:notify) { $script:notify.Visible = $false; $script:notify.Dispose() }
    if ($script:settingsSignal) { $script:settingsSignal.Dispose() }
    if ($script:menu) { $script:menu.Dispose() }
    if ($script:icon -and $script:icon -ne [System.Drawing.SystemIcons]::Application) { $script:icon.Dispose() }
    $singleInstance.ReleaseMutex()
    $singleInstance.Dispose()
}
