# End-to-end installation test on the real Windows PowerShell 5.1 runner.
# Runs the same entry-point a user downloads, without spawning the tray GUI.
$ErrorActionPreference = 'Stop'
$originalLocal = $env:LOCALAPPDATA
$root = Join-Path ([IO.Path]::GetTempPath()) ('SnipToPath-e2e-' + [guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA = Join-Path $root 'LocalAppData'
$incoming = Join-Path $root 'incoming.ps1'
$installed = Join-Path $env:LOCALAPPDATA 'SnipToPath\SnipToPath.ps1'
$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..\SnipToPath.ps1')).Path
$installedReady = $false

function Invoke-SnipInstallation([string]$file) {
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $file -NoLaunch
    if ($LASTEXITCODE -ne 0) {
        throw "SnipToPath installation failed (exit $LASTEXITCODE)."
    }
}

try {
    [void][IO.Directory]::CreateDirectory($root)
    Copy-Item -LiteralPath $source -Destination $incoming

    Invoke-SnipInstallation $incoming
    if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {
        throw 'Fresh installation did not create the application file.'
    }
    $installedReady = $true
    if ((Get-FileHash $source -Algorithm SHA256).Hash -ne (Get-FileHash $installed -Algorithm SHA256).Hash) {
        throw 'Fresh installation contents do not match downloaded source.'
    }
    Write-Host 'PASS full first-time installation (no tray launched)'

    # Mimic the previous version in the installation directory.
    $settingsPath = Join-Path $env:LOCALAPPDATA 'SnipToPath\settings.json'
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $settings.Enabled = $false
    $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    [IO.File]::WriteAllText($installed, '# Old SnipToPath installer version', [Text.Encoding]::UTF8)

    Invoke-SnipInstallation $incoming
    if ((Get-FileHash $source -Algorithm SHA256).Hash -ne (Get-FileHash $installed -Algorithm SHA256).Hash) {
        throw 'Upgrade did not replace legacy script.'
    }
    $updatedSettings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($updatedSettings.Enabled -ne $false) {
        throw 'Upgrade lost the previous user settings.'
    }
    Write-Host 'PASS full upgrade from previously installed version; settings preserved'

    Invoke-SnipInstallation $installed
    Write-Host 'PASS re-running installed script (same source and destination)'

    $spareFiles = @(Get-ChildItem (Split-Path -Parent $installed) -File |
        Where-Object { $_.Name -match '^SnipToPath-[a-f0-9]{32}\.(tmp|bak)$' })
    if ($spareFiles.Count) { throw 'Full installer left temporary or backup files.' }
    Write-Host 'PASS no lingering update staging files'
}
finally {
    if ($installedReady -and (Test-Path -LiteralPath $installed -PathType Leaf)) {
        & $powershell -NoProfile -ExecutionPolicy Bypass -File $installed -Uninstall
        if ($LASTEXITCODE -ne 0) { Write-Warning "Uninstall cleanup exited with $LASTEXITCODE." }
    }
    $env:LOCALAPPDATA = $originalLocal
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
