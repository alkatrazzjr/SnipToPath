# Remove SnipToPath from the current Windows user account.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$installed = Join-Path $env:LOCALAPPDATA 'SnipToPath\SnipToPath.ps1'
if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {
    Write-Host 'SnipToPath is not installed.'
    return
}
$exe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $exe -NoProfile -ExecutionPolicy Bypass -File $installed -Uninstall
if ($LASTEXITCODE -ne 0) { throw "Uninstall exited with code $LASTEXITCODE." }
