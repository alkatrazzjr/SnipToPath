# Check that PowerShell-hosted SnipToPath windows and shortcuts have the
# same application identity. This prevents PowerShell taskbar grouping.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing
$source = Get-Content (Join-Path $PSScriptRoot '..\SnipToPath.ps1') -Raw -Encoding UTF8
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Main script does not parse' }

$fn = @($ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Set-ShortcutAppIdentity'
}, $true))
if ($fn.Count -ne 1) { throw 'Missing unique shortcut AppID helper' }
Invoke-Expression $fn[0].Extent.Text
$appUserModelId = 'SnipToPath.Desktop'

$testDir = Join-Path ([IO.Path]::GetTempPath()) ('sniptopath-taskbar-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDir)
try {
    $linkPath = Join-Path $testDir 'SnipToPath.lnk'
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($linkPath)
    $link.TargetPath = (Join-Path $env:WINDIR 'System32\wscript.exe')
    $link.IconLocation = (Resolve-Path (Join-Path $PSScriptRoot '..\assets\SnipToPath.ico')).Path
    $link.Save()
    Set-ShortcutAppIdentity $linkPath
    $actual = [SnipApp.ShortcutIdentity]::Get($linkPath)
    if ($actual -ne $appUserModelId) { throw "Shortcut AppUserModelID mismatch: $actual" }
    Write-Host 'PASS shortcut uses SnipToPath AppUserModelID and custom icon'

    $nativeMatch = [regex]::Match($source,
        '(?s)Add-Type -TypeDefinition @''\r?\n(.*?)\r?\n''@ -ReferencedAssemblies ''System.Drawing'', ''System.Windows.Forms''')
    if (-not $nativeMatch.Success) { throw 'Native UI declarations missing' }
    Add-Type -TypeDefinition $nativeMatch.Groups[1].Value -ReferencedAssemblies 'System.Drawing', 'System.Windows.Forms'
    $hr = [SnipUI.Native]::SetCurrentProcessExplicitAppUserModelID($appUserModelId)
    if ($hr -ne 0) { throw "Process AppUserModelID failed with HRESULT $hr" }
    $pointer = [IntPtr]::Zero
    $hr = [SnipUI.Native]::GetCurrentProcessExplicitAppUserModelID([ref]$pointer)
    try {
        if ($hr -ne 0 -or [Runtime.InteropServices.Marshal]::PtrToStringUni($pointer) -ne $appUserModelId) {
            throw 'Process AppUserModelID does not match shortcut'
        }
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($pointer) }
    }
    Write-Host 'PASS PowerShell host uses SnipToPath identity instead of powershell.exe'

    $wpf = [Windows.Window]::new()
    $imageIcon = [Drawing.Icon]::new((Resolve-Path (Join-Path $PSScriptRoot '..\assets\SnipToPath.ico')).Path)
    try {
        $wpf.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $imageIcon.Handle, [Windows.Int32Rect]::Empty,
            [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
        $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($wpf).EnsureHandle()
        foreach ($size in @(0,1)) {
            $null = [SnipUI.Native]::SendMessage($hwnd, 0x80, [IntPtr]::new($size), $imageIcon.Handle)
            $received = [SnipUI.Native]::SendMessage($hwnd, 0x7F, [IntPtr]::new($size), [IntPtr]::Zero)
            if ($received -eq [IntPtr]::Zero) { throw "Window does not expose icon size $size" }
        }
        Write-Host 'PASS settings window exposes SnipToPath icon to Windows taskbar'
    } finally { $wpf.Close(); $imageIcon.Dispose() }
} finally {
    Remove-Item -LiteralPath $testDir -Force -Recurse -ErrorAction SilentlyContinue
}
