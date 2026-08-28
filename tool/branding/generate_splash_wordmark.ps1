param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..', '..')
)
$flutterAsset = [System.IO.Path]::Combine(
    $projectRoot,
    'assets',
    'branding',
    'bil_splash_identity.png'
)
$androidAsset = [System.IO.Path]::Combine(
    $projectRoot,
    'android',
    'app',
    'src',
    'main',
    'res',
    'drawable-nodpi',
    'bil_splash_identity.png'
)
$iosAsset = [System.IO.Path]::Combine(
    $projectRoot,
    'ios',
    'Runner',
    'Assets.xcassets',
    'BILLaunchWordmark.imageset',
    'BILLaunchWordmark.png'
)
$temporaryAsset = [System.IO.Path]::Combine(
    $projectRoot,
    'tool',
    'branding',
    'bil_splash_identity.generated.png'
)

$targets = @($flutterAsset, $androidAsset, $iosAsset, $temporaryAsset)
foreach ($target in $targets) {
    if (-not $target.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Splash asset target escaped the project root: $target"
    }
}

# Android 12+ masks its system splash icon. A square transparent raster keeps
# the complete long identity inside the documented 192dp safe circle. Flutter
# and iOS render these exact same pixels, producing a seamless hand-off.
$canvas = New-Object System.Drawing.Bitmap(
    864,
    864,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
try {
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        # A condensed display face keeps the complete product name readable at
        # native splash size. The trademark is intentionally large enough to
        # remain visible on a physical phone, per the final brand direction.
        $wordmarkFont = New-Object System.Drawing.Font(
            'Bahnschrift Condensed',
            64,
            [System.Drawing.FontStyle]::Bold,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $tmFont = New-Object System.Drawing.Font(
            'Bahnschrift Condensed',
            78,
            [System.Drawing.FontStyle]::Bold,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        if ($wordmarkFont.Name -ne 'Bahnschrift Condensed' -or $tmFont.Name -ne 'Bahnschrift Condensed') {
            throw 'Bahnschrift Condensed is required to generate the canonical BIL splash identity.'
        }

        $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $format = [System.Drawing.StringFormat]::GenericTypographic
        try {
            $wordmark = 'BODY INTELLIGENCE LOG'
            $trademark = [char]0x2122
            $wordmarkSize = $graphics.MeasureString($wordmark, $wordmarkFont, 2000, $format)
            $tmSize = $graphics.MeasureString($trademark, $tmFont, 2000, $format)
            # Float the larger TM above the terminal G so both elements grow
            # without forcing the complete name outside Android's safe zone.
            $tmOverlap = 28.0
            $contentWidth = $wordmarkSize.Width - $tmOverlap + $tmSize.Width
            if ($contentWidth -gt 576) {
                throw "Splash identity exceeds Android's 192dp safe circle: $contentWidth pixels"
            }

            $wordmarkX = (864.0 - $contentWidth) / 2.0
            $wordmarkY = (864.0 - $wordmarkSize.Height) / 2.0
            $tmX = $wordmarkX + $wordmarkSize.Width - $tmOverlap
            $tmY = $wordmarkY - 35.0
            $graphics.DrawString($wordmark, $wordmarkFont, $white, $wordmarkX, $wordmarkY, $format)
            $graphics.DrawString($trademark, $tmFont, $white, $tmX, $tmY, $format)
        } finally {
            $white.Dispose()
            $wordmarkFont.Dispose()
            $tmFont.Dispose()
        }
    } finally {
        $graphics.Dispose()
    }

    $canvas.Save($temporaryAsset, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $canvas.Dispose()
}

foreach ($target in @($flutterAsset, $androidAsset, $iosAsset)) {
    $targetDirectory = [System.IO.Path]::GetDirectoryName($target)
    [System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
    Copy-Item -LiteralPath $temporaryAsset -Destination $target -Force
}
[System.IO.File]::Delete($temporaryAsset)

Write-Output 'Generated one pixel-identical BODY INTELLIGENCE LOG splash identity for Flutter, Android, and iOS.'
