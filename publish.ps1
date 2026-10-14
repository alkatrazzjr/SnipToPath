# Optional one-time bootstrap for the repository owner: create AND push SnipToPath on GitHub.
# Requires Git and GitHub CLI (gh) already installed and authenticated.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$owner = 'alkatrazzjr'
$repo = 'SnipToPath'
$fullName = "$owner/$repo"
Set-Location -LiteralPath $PSScriptRoot
foreach ($command in @('git','gh')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing $command. Install it and authenticate with 'gh auth login' before publishing."
    }
}
$login = (& gh api user --jq '.login' 2>$null)
if ($LASTEXITCODE -ne 0 -or $login -ine $owner) {
    throw "Log in to GitHub CLI as $owner using 'gh auth login' first. Current login: $login"
}
& gh repo view $fullName --json name -q '.name' 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    throw "Repository $fullName already exists. Do not run this bootstrap again."
}
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git')) {
    throw 'This folder already contains a .git repository. Publish it manually instead.'
}
& git init -b main
if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
& git add .
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
& git commit -m 'feat: initial SnipToPath source and documentation'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed; set git user.name and user.email first' }
& gh repo create $fullName --public --source . --remote origin --push
if ($LASTEXITCODE -ne 0) { throw 'GitHub repository creation or upload failed; check gh output.' }
Write-Host "Published: https://github.com/$fullName" -ForegroundColor Green
Write-Host 'Next: check the Windows CI workflow, perform a real clipboard/tray test, then tag v0.1.0 to trigger a release.'
