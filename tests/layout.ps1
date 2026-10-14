# Check actual WPF content measurements, not only whether the XAML parses.
# Windows GitHub runners use Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$source = Get-Content (Join-Path $PSScriptRoot '..\SnipToPath.ps1') -Raw -Encoding UTF8

$m = [regex]::Match($source, '(?s)\$xaml\s*=\s*@''\r?\n(.*?)\r?\n''@')
if (-not $m.Success) { throw 'Settings XAML is missing' }

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
foreach ($fn in @('Get-TranslationTable','Get-EffectiveLanguage','Translate-UI','Update-WpfLanguage')) {
    $defs = @($ast.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $fn
    }, $true))
    if ($defs.Count -ne 1) { throw "Missing locale function: $fn" }
    Invoke-Expression $defs[0].Extent.Text
}
$script:translationsEn = Get-TranslationTable
$script:translationsRu = @{}
foreach ($key in $script:translationsEn.Keys) {
    $value = [string]$script:translationsEn[$key]
    if (-not $script:translationsRu.ContainsKey($value)) { $script:translationsRu[$value] = $key }
}

foreach ($lang in @('ru', 'en')) {
    foreach ($width in @(720, 654)) {
        $window = [Windows.Markup.XamlReader]::Parse($m.Groups[1].Value)
        try {
            $script:config = @{ LanguageMode = $(if ($lang -eq 'ru') { 'Ru' } else { 'En' }) }
            Update-WpfLanguage $window
            # Client area at the default 720px window height (title bar excluded).
            $client = [Windows.Size]::new($width, 688)
            $window.Content.Measure($client)
            $window.Content.Arrange([Windows.Rect]::new(0, 0, $client.Width, $client.Height))
            $window.Content.UpdateLayout()

            $scroll = @($window.Content.Children | Where-Object {
                $_ -is [System.Windows.Controls.ScrollViewer]
            })
            if ($scroll.Count -ne 1) { throw 'Expected exactly one responsive settings scroller' }
            $viewer = $scroll[0]
            $overflowY = [Math]::Max(0, $viewer.ExtentHeight - $viewer.ViewportHeight)
            $overflowX = [Math]::Max(0, $viewer.ExtentWidth - $viewer.ViewportWidth)
            Write-Host ("Layout {0} at {1}px client width: viewport={2:N1}x{3:N1}, extent={4:N1}x{5:N1}, overflow={6:N1}x{7:N1}" -f
                $lang,$width,$viewer.ViewportWidth,$viewer.ViewportHeight,$viewer.ExtentWidth,$viewer.ExtentHeight,
                $overflowX,$overflowY)
            if ($overflowY -gt 1.5) { throw "Settings require scrolling at the default window size (width $width)" }
            if ($overflowX -gt 1.5) { throw "Settings are too wide at width $width" }
            if ($window.FindName('LanguageAuto') -eq $null -or $window.FindName('SaveFolderButton') -eq $null) {
                throw 'Settings controls not accessible after balanced layout'
            }

            # The scrollbar is a deliberate fallback on short screens, not something
            # permanently removed. Verify the layout responds to a short viewport.
            $small = [Windows.Size]::new($width, 425)
            $window.Content.Measure($small)
            $window.Content.Arrange([Windows.Rect]::new(0, 0, $small.Width, $small.Height))
            $window.Content.UpdateLayout()
            if ($viewer.ScrollableHeight -le 1) {
                throw 'Short-window scrolling fallback is broken'
            }
        }
        finally { $window.Close() }
    }
}
Write-Host 'PASS default-height layout fits without scrolling; short screens can scroll'
