# SnipToPath online installer. Run in Windows PowerShell (without admin permissions).
[CmdletBinding()]
param([ValidatePattern('^[A-Za-z0-9._/-]+$')][string]$Ref = 'main')
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'SnipToPath requires Windows 10/11.' }
$download = Join-Path ([IO.Path]::GetTempPath()) ('SnipToPath-install-{0}.ps1' -f [guid]::NewGuid().ToString('N'))
# A unique query string avoids stale CDN/proxy copies immediately after updates.
$nonce = [guid]::NewGuid().ToString('N')
$uri = "https://raw.githubusercontent.com/alkatrazzjr/SnipToPath/$Ref/SnipToPath.ps1?nocache=$nonce"
try {
    Write-Host "Downloading SnipToPath from $uri ..."
    Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers @{ 'Cache-Control' = 'no-cache' } -OutFile $download -ErrorAction Stop
    if ((Get-Item -LiteralPath $download).Length -lt 10000) { throw 'Unexpected download contents.' }
    $sourceText = Get-Content -LiteralPath $download -Raw -Encoding UTF8
    if ($sourceText.Contains('[IO.File]::Replace(')) {
        throw 'A cached/older installer version was downloaded. Retry the installation.'
    }
    $checksum = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
    Write-Host ('Downloaded script SHA256: {0}' -f $checksum)
    $shell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $shell -NoProfile -ExecutionPolicy Bypass -File $download
    if ($LASTEXITCODE -ne 0) { throw "SnipToPath setup exited with code $LASTEXITCODE." }
}
finally {
    Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
}
