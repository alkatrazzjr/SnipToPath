# Test auto language selection, translation coverage and live WPF switching on Windows.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$source = Get-Content (Join-Path $PSScriptRoot '..\SnipToPath.ps1') -Raw -Encoding UTF8
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Source PowerShell syntax invalid' }

foreach ($functionName in @('Get-TranslationTable','Get-EffectiveLanguage','Translate-UI','Update-WpfLanguage')) {
    $def = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
    }, $true))
    if ($def.Count -ne 1) { throw "Expected one function: $functionName" }
    Invoke-Expression $def[0].Extent.Text
}

$script:translationsEn = Get-TranslationTable
$script:translationsRu = @{}
foreach ($key in $script:translationsEn.Keys) {
    $english = [string]$script:translationsEn[$key]
    if (-not $script:translationsRu.ContainsKey($english)) { $script:translationsRu[$english] = $key }
}

$script:config = @{ LanguageMode = 'Auto' }
if ((Get-EffectiveLanguage 'ru-RU') -ne 'Ru' -or
    (Get-EffectiveLanguage 'ru-KZ') -ne 'Ru' -or
    (Get-EffectiveLanguage 'en-US') -ne 'En' -or
    (Get-EffectiveLanguage 'de-DE') -ne 'En' -or
    (Get-EffectiveLanguage 'uk-UA') -ne 'En') {
    throw 'Automatic Windows UI culture detection is incorrect'
}
$script:config.LanguageMode = 'Ru'
if ((Get-EffectiveLanguage 'en-US') -ne 'Ru') { throw 'Russian manual override failed' }
$script:config.LanguageMode = 'En'
if ((Get-EffectiveLanguage 'ru-RU') -ne 'En') { throw 'English manual override failed' }
Write-Host 'PASS automatic Windows locale and manual language overrides'

foreach ($windowName in @('xaml','quickXaml')) {
    $pattern = '(?s)\$' + $windowName + '\s*=\s*@''\r?\n(.*?)\r?\n''@'
    $m = [regex]::Match($source, $pattern)
    if (-not $m.Success) { throw "Missing XAML for $windowName" }
    $markup = $m.Groups[1].Value

    # Every Russian label must have a translation; don't let a future UI change regress.
    foreach ($attribute in [regex]::Matches($markup, '(?:Text|Content|Title)="([^"]+)"')) {
        $value = [System.Net.WebUtility]::HtmlDecode($attribute.Groups[1].Value)
        if ($value -match '[А-Яа-яЁё]' -and -not $script:translationsEn.ContainsKey($value)) {
            throw "Untranslated UI string in $windowName : $value"
        }
    }

    $window = [Windows.Markup.XamlReader]::Parse($markup)
    try {
        $script:config.LanguageMode = 'En'
        Update-WpfLanguage $window
        if ($windowName -eq 'xaml') {
            if ($window.Title -ne 'SnipToPath - Settings') { throw 'English settings title missing' }
            if ($window.FindName('CloseButton').Content -ne 'Close') { throw 'English settings action missing' }
            if ($window.FindName('LanguageAuto').Content -ne 'Automatic') { throw 'Automatic selector not localized' }
            if ($window.FindName('LanguageRu').Content -ne 'Русский') { throw 'Native language selector missing' }
            if ($window.FindName('LanguageEn').Content -ne 'English') { throw 'English selector missing' }
        }
        else {
            if ($window.FindName('QuickSettings').Content -ne 'Settings') { throw 'Tray settings not localized' }
            if ($window.FindName('QuickEnabled').Content.Children[0].Text -ne 'Process images') {
                throw 'Tray nested label not translated'
            }
        }
        $script:config.LanguageMode = 'Ru'
        Update-WpfLanguage $window
        if ($windowName -eq 'xaml') {
            if ($window.Title -ne 'SnipToPath — Настройки') { throw 'Russian settings title was not restored' }
            if ($window.FindName('CloseButton').Content -ne 'Закрыть') { throw 'Russian settings action was not restored' }
        }
        else {
            if ($window.FindName('QuickSettings').Content -ne 'Настройки') { throw 'Tray settings not restored to Russian' }
        }
    }
    finally { $window.Close() }
}
Write-Host 'PASS all RU/EN WPF labels and switching language without restarting'

# Existing settings must default to Auto without erasing their other fields.
foreach ($name in @('Get-Defaults','Load-Settings')) {
    $defs = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true))
    if ($defs.Count -ne 1) { throw "Missing $name" }
    Invoke-Expression $defs[0].Extent.Text
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('sniptopath-locale-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$settingsPath = Join-Path $root 'settings.json'
try {
    [IO.File]::WriteAllText($settingsPath, '{"Enabled":false,"DeleteDelaySeconds":420}', [Text.Encoding]::UTF8)
    Load-Settings
    if ($script:config.LanguageMode -ne 'Auto' -or $script:config.Enabled -ne $false -or
        [int]$script:config.DeleteDelaySeconds -ne 420) { throw 'Legacy configuration migration failed' }

    [IO.File]::WriteAllText($settingsPath, '{"LanguageMode":"En","Enabled":false}', [Text.Encoding]::UTF8)
    Load-Settings
    if ($script:config.LanguageMode -ne 'En') { throw 'Manual language preference not retained' }

    [IO.File]::WriteAllText($settingsPath, '{"LanguageMode":"Unsupported"}', [Text.Encoding]::UTF8)
    Load-Settings
    if ($script:config.LanguageMode -ne 'Auto') { throw 'Invalid language setting must fall back to Auto' }
}
finally { Remove-Item -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue }
Write-Host 'PASS older settings migration and saved language preference'
