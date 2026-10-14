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

            # Filled text fields must keep the native WPF text host and usable
            # vertical space. The old custom ScrollViewer clipped both values.
            $delayInput = $window.FindName('DeleteDelayInput')
            $folderInput = $window.FindName('FolderPathInput')
            $delayInput.Text = '300'
            $folderInput.Text = 'C:\Users\Demo\AppData\Local\Temp\SnipToPath'
            $window.Content.UpdateLayout()
            $inputStyle = $window.Resources['RoundedInput']
            if (@($inputStyle.Setters | Where-Object { $_.Property.Name -eq 'Template' }).Count -ne 0) {
                throw 'Custom TextBox template must not override WPF text rendering'
            }
            foreach ($inputBox in @($delayInput, $folderInput)) {
                if ($inputBox.Padding.Top -ne 0 -or $inputBox.Padding.Bottom -ne 0) {
                    throw 'TextBox padding clips native WPF content'
                }
                $inputBox.ApplyTemplate() | Out-Null
                $contentHost = $inputBox.Template.FindName('PART_ContentHost', $inputBox)
                if (-not $contentHost) { throw 'Native TextBox content host not found' }
                if ($inputBox.ActualHeight -lt 30) { throw 'Text input height is too small' }
            }
            Write-Host "PASS native input hosts and 35px fields ($lang, width $width)"

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
            # Test the actual visible WPF scrollbar, not only XAML syntax:
            # short windows must show the narrow themed scrollbar.
            $viewer.ApplyTemplate() | Out-Null
            $bar = $viewer.Template.FindName('PART_VerticalScrollBar', $viewer)
            if ($null -eq $bar) { throw 'Settings vertical scrollbar is missing' }
            if ($bar.Visibility -ne [System.Windows.Visibility]::Visible) {
                throw 'Scrollbar should be visible when the settings window is short'
            }
            if ([Math]::Abs($bar.Width - 12) -gt 0.1) {
                throw 'The old full-width system scrollbar is still in use'
            }
            $bar.ApplyTemplate() | Out-Null
            $track = $bar.Template.FindName('PART_Track', $bar)
            if ($null -eq $track -or $null -eq $track.Thumb) {
                throw 'Custom scrollbar track or draggable thumb is missing'
            }
            foreach ($variant in @(
                @{ Name='light'; Page='#F3F3F3'; Thumb='#A0A5AF' },
                @{ Name='dark'; Page='#17181A'; Thumb='#5D6470' }
            )) {
                $page = [Windows.Media.ColorConverter]::ConvertFromString($variant.Page)
                $thumbColor = [Windows.Media.ColorConverter]::ConvertFromString($variant.Thumb)
                $window.Resources['PageBrush'] = [Windows.Media.SolidColorBrush]::new($page)
                $window.Resources['ScrollThumbBrush'] = [Windows.Media.SolidColorBrush]::new($thumbColor)
                $window.Content.UpdateLayout()
                if ($bar.Background.Color -ne $page) {
                    throw "Scrollbar track doesn't follow the $($variant.Name) theme"
                }
                if ($track.Thumb.Background.Color -ne $thumbColor) {
                    throw "Scrollbar thumb doesn't follow the $($variant.Name) theme"
                }
            }
            $viewer.ScrollToVerticalOffset($viewer.ScrollableHeight)
            $viewer.UpdateLayout()
            if ($viewer.VerticalOffset -lt ($viewer.ScrollableHeight - 1.5)) {
                throw 'Settings cannot scroll down to the last section'
            }
            Write-Host "PASS theme-aware draggable scrollbar on short windows ($lang, $width)"
        }
        finally { $window.Close() }
    }
}
Write-Host 'PASS default-height layout fits without scrolling; short screens can scroll'
