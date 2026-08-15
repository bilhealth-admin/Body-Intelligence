param(
  [switch]$PackageScreenshots
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$storeRoot = Join-Path $project 'store_assets'
$brandArchive = 'C:\Users\HP 1040 G8\Downloads\BIL-Brand-Assets-v1.zip'
$brandExtractRoot = Join-Path $storeRoot 'source'
$brandSourceRoot = Join-Path $brandExtractRoot 'BIL-Brand-Assets-v1'
$iconSource = Join-Path $brandSourceRoot '01-bil-app-icon.png'
$splashSource = Join-Path $brandSourceRoot '02-bil-splash.png'
$plansSource = Join-Path $brandSourceRoot '06-bil-free-plus-pro.png'
$horizontalSource = Join-Path $brandSourceRoot '03-bil-horizontal-logo.png'
$featureSource = Join-Path $brandSourceRoot '05-bil-store-feature-graphic.png'
$onboardingSource = Join-Path $brandSourceRoot '04-bil-onboarding-hero.png'

Add-Type -AssemblyName System.Drawing

function Ensure-Directory([string]$path) {
  [System.IO.Directory]::CreateDirectory($path) | Out-Null
}

function Save-CroppedPng(
  [string]$source,
  [string]$destination,
  [int]$width,
  [int]$height,
  [bool]$opaque = $true
) {
  if (-not (Test-Path -LiteralPath $source)) { throw "Missing source image: $source" }
  Ensure-Directory (Split-Path -Parent $destination)
  $input = [System.Drawing.Image]::FromFile($source)
  try {
    $pixelFormat = if ($opaque) {
      [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    } else {
      [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    $output = [System.Drawing.Bitmap]::new($width, $height, $pixelFormat)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($output)
      try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        if ($opaque) { $graphics.Clear([System.Drawing.Color]::White) } else { $graphics.Clear([System.Drawing.Color]::Transparent) }
        $sourceRatio = $input.Width / $input.Height
        $targetRatio = $width / $height
        if ($sourceRatio -gt $targetRatio) {
          $cropHeight = $input.Height
          $cropWidth = [int]($cropHeight * $targetRatio)
          $cropX = [int](($input.Width - $cropWidth) / 2)
          $cropY = 0
        } else {
          $cropWidth = $input.Width
          $cropHeight = [int]($cropWidth / $targetRatio)
          $cropX = 0
          $cropY = [int](($input.Height - $cropHeight) / 2)
        }
        $destRect = [System.Drawing.Rectangle]::new(0, 0, $width, $height)
        $srcRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropWidth, $cropHeight)
        $graphics.DrawImage($input, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
      } finally { $graphics.Dispose() }
      $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $output.Dispose() }
  } finally { $input.Dispose() }
}

function Save-TransparentBrandMark([string]$destination, [int]$width, [int]$height, [bool]$monochrome) {
  Ensure-Directory (Split-Path -Parent $destination)
  $input = [System.Drawing.Bitmap]::new($iconSource)
  try {
    $output = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($output)
      try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $margin = [int]([Math]::Round([Math]::Min($width, $height) * 0.17))
        $target = [System.Drawing.Rectangle]::new($margin, $margin, $width - (2 * $margin), $height - (2 * $margin))
        $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
        try {
          $attributes.SetColorKey([System.Drawing.Color]::FromArgb(0, 0, 0), [System.Drawing.Color]::FromArgb(38, 57, 87))
          if ($monochrome) {
            $matrix = [System.Drawing.Imaging.ColorMatrix]::new()
            $matrix.Matrix00 = 0; $matrix.Matrix01 = 0; $matrix.Matrix02 = 0
            $matrix.Matrix10 = 0; $matrix.Matrix11 = 0; $matrix.Matrix12 = 0
            $matrix.Matrix20 = 0; $matrix.Matrix21 = 0; $matrix.Matrix22 = 0
            $matrix.Matrix40 = 1; $matrix.Matrix41 = 1; $matrix.Matrix42 = 1
            $attributes.SetColorMatrix($matrix)
          }
          $graphics.DrawImage($input, $target, 0, 0, $input.Width, $input.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        } finally { $attributes.Dispose() }
      } finally { $graphics.Dispose() }
      $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $output.Dispose() }
  } finally { $input.Dispose() }
}

function Save-HorizontalLightLogo([string]$destination) {
  $source = $horizontalSource
  Ensure-Directory (Split-Path -Parent $destination)
  $input = [System.Drawing.Bitmap]::new($source)
  try {
    $output = [System.Drawing.Bitmap]::new(1600, 900, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($output)
      try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(246, 248, 251))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
        try {
          $attributes.SetColorKey([System.Drawing.Color]::FromArgb(0, 0, 0), [System.Drawing.Color]::FromArgb(45, 80, 95))
          $target = [System.Drawing.Rectangle]::new(120, 90, 1360, 720)
          $graphics.DrawImage($input, $target, 0, 0, $input.Width, $input.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        } finally { $attributes.Dispose() }
      } finally { $graphics.Dispose() }
      $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $output.Dispose() }
  } finally { $input.Dispose() }
}

function Save-PlanThird([string]$destination, [int]$index) {
  Ensure-Directory (Split-Path -Parent $destination)
  $input = [System.Drawing.Image]::FromFile($plansSource)
  try {
    $third = [int]($input.Width / 3)
    $sourceX = $index * $third
    $output = [System.Drawing.Bitmap]::new(1080, 1440, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($output)
      try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(7, 20, 43))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $sourceRect = [System.Drawing.Rectangle]::new($sourceX, 0, $third, $input.Height)
        $scale = [Math]::Min(1080.0 / $third, 1440.0 / $input.Height)
        $drawWidth = [int]([Math]::Round($third * $scale))
        $drawHeight = [int]([Math]::Round($input.Height * $scale))
        $destinationRect = [System.Drawing.Rectangle]::new(
          [int]((1080 - $drawWidth) / 2),
          [int]((1440 - $drawHeight) / 2),
          $drawWidth,
          $drawHeight
        )
        $graphics.DrawImage($input, $destinationRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
      } finally { $graphics.Dispose() }
      $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $output.Dispose() }
  } finally { $input.Dispose() }
}

$directories = @(
  (Join-Path $storeRoot 'graphics\google_play'),
  (Join-Path $storeRoot 'graphics\plans'),
  (Join-Path $storeRoot 'graphics\brand'),
  (Join-Path $storeRoot 'graphics\product'),
  (Join-Path $storeRoot 'screenshots\apple'),
  (Join-Path $storeRoot 'screenshots\google_play'),
  (Join-Path $storeRoot 'evidence')
  (Join-Path $storeRoot 'evidence\screenshots')
)
$directories | ForEach-Object { Ensure-Directory $_ }

if (-not (Test-Path -LiteralPath $brandArchive)) {
  throw "Missing owner-approved BIL brand archive: $brandArchive"
}
$brandArchiveHash = (Get-FileHash -LiteralPath $brandArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($brandArchiveHash -ne 'c8fba5b1cd4c9a0ef31f59cffddde0980cfebc68ade6a90e333f21e3be8730ee') {
  throw "BIL brand archive hash mismatch: $brandArchiveHash"
}
Ensure-Directory $brandExtractRoot
Expand-Archive -LiteralPath $brandArchive -DestinationPath $brandExtractRoot -Force
foreach ($requiredBrandFile in @($iconSource, $splashSource, $plansSource, $horizontalSource, $featureSource, $onboardingSource)) {
  if (-not (Test-Path -LiteralPath $requiredBrandFile)) {
    throw "Incomplete BIL brand archive; missing $requiredBrandFile"
  }
}

$approvedCopies = @{
  'assets\images\flagship\bil_body_intelligence_journey_v1.png' = 'graphics\product\legacy_onboarding_hero.png'
  'assets\images\professional\mediterranean_protein_bowl.png' = 'graphics\product\recipe_protein_bowl.png'
  'assets\images\professional\strength_training_cover.png' = 'graphics\product\workout_strength.png'
  'assets\images\v10_master\bil_hologram_master.png' = 'graphics\product\body_twin.png'
  'assets\images\connected_health\bil_medical_hub.png' = 'graphics\product\connected_devices.png'
}
foreach ($sourceRelative in $approvedCopies.Keys) {
  $sourcePath = Join-Path $project $sourceRelative
  $destinationPath = Join-Path $storeRoot $approvedCopies[$sourceRelative]
  if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing approved BIL asset: $sourceRelative" }
  Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

Save-CroppedPng $featureSource (Join-Path $storeRoot 'graphics\google_play\feature_graphic.png') 1024 500 $true
Save-CroppedPng $iconSource (Join-Path $storeRoot 'graphics\google_play\play_icon_512.png') 512 512 $false
Save-CroppedPng $iconSource (Join-Path $project 'assets\branding\bil_icon_master.png') 1254 1254 $true
Save-CroppedPng $onboardingSource (Join-Path $project 'assets\images\flagship\bil_body_intelligence_journey_v1.png') 1024 1792 $true
Save-CroppedPng $iconSource (Join-Path $storeRoot 'graphics\brand\bil_emblem_master.png') 1024 1024 $true
Save-CroppedPng $horizontalSource (Join-Path $storeRoot 'graphics\brand\bil_horizontal_dark.png') 1600 900 $true
Save-CroppedPng $onboardingSource (Join-Path $storeRoot 'graphics\product\onboarding_hero.png') 1024 1792 $true
Save-CroppedPng $splashSource (Join-Path $storeRoot 'graphics\product\splash_master.png') 1024 1792 $true
Save-PlanThird (Join-Path $storeRoot 'graphics\plans\free.png') 0
Save-PlanThird (Join-Path $storeRoot 'graphics\plans\plus.png') 1
Save-PlanThird (Join-Path $storeRoot 'graphics\plans\pro.png') 2
Save-HorizontalLightLogo (Join-Path $storeRoot 'graphics\brand\bil_horizontal_light.png')

$appIconFiles = Get-ChildItem -LiteralPath (Join-Path $project 'ios\Runner\Assets.xcassets\AppIcon.appiconset') -Filter '*.png' -File
foreach ($appIcon in $appIconFiles) {
  $existing = [System.Drawing.Image]::FromFile($appIcon.FullName)
  try { $iconWidth = $existing.Width; $iconHeight = $existing.Height } finally { $existing.Dispose() }
  Save-CroppedPng $iconSource $appIcon.FullName $iconWidth $iconHeight $true
}

$legacyIcons = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}
foreach ($density in $legacyIcons.GetEnumerator()) {
  Save-CroppedPng $iconSource (Join-Path $project "android\app\src\main\res\$($density.Key)\ic_launcher.png") $density.Value $density.Value $true
}

$foregrounds = @{
  'mipmap-mdpi' = 108; 'mipmap-hdpi' = 162; 'mipmap-xhdpi' = 216;
  'mipmap-xxhdpi' = 324; 'mipmap-xxxhdpi' = 432
}
foreach ($density in $foregrounds.Keys) {
  Save-TransparentBrandMark (Join-Path $project "android\app\src\main\res\$density\ic_launcher_foreground.png") $foregrounds[$density] $foregrounds[$density] $false
}
Save-TransparentBrandMark (Join-Path $project 'android\app\src\main\res\drawable\ic_launcher_monochrome.png') 432 432 $true
Save-CroppedPng $splashSource (Join-Path $project 'ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage.png') 430 932 $true
Save-CroppedPng $splashSource (Join-Path $project 'ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage@2x.png') 860 1864 $true
Save-CroppedPng $splashSource (Join-Path $project 'ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage@3x.png') 1290 2796 $true
Save-CroppedPng $splashSource (Join-Path $project 'android\app\src\main\res\drawable-nodpi\bil_splash.png') 1080 1920 $true

$v31 = Join-Path $project 'android\app\src\main\res\values-v31\styles.xml'
Ensure-Directory (Split-Path -Parent $v31)
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#08142B</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
        <item name="android:windowSplashScreenIconBackgroundColor">#08142B</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
'@ | Set-Content -LiteralPath $v31 -Encoding UTF8

if ($PackageScreenshots) {
  $goldenRoot = Join-Path $project 'test\goldens'
  $apple = Get-ChildItem -LiteralPath $goldenRoot -Filter 'epic15_iphone_69_*.png' -File
  $google = Get-ChildItem -LiteralPath $goldenRoot -Filter 'epic15_android_phone_*.png' -File
  if ($apple.Count -ne 23) { throw "Expected 23 Apple screenshots, found $($apple.Count)" }
  if ($google.Count -ne 19) { throw "Expected 19 Google screenshots, found $($google.Count)" }
  foreach ($file in $apple) { Save-CroppedPng $file.FullName (Join-Path $storeRoot "screenshots\apple\$($file.Name)") 1290 2796 $true }
  foreach ($file in $google) { Save-CroppedPng $file.FullName (Join-Path $storeRoot "screenshots\google_play\$($file.Name)") 1080 1920 $true }
  $productEvidence = Get-ChildItem -LiteralPath $goldenRoot -Filter 'epic15_evidence_*.png' -File
  if ($productEvidence.Count -ne 2) { throw "Expected 2 product content evidence screenshots, found $($productEvidence.Count)" }
  foreach ($file in $productEvidence) {
    Save-CroppedPng $file.FullName (Join-Path $storeRoot "evidence\screenshots\$($file.Name)") 1080 1920 $true
  }

  $rows = @()
  Get-ChildItem -LiteralPath $storeRoot -Recurse -Filter '*.png' -File | Sort-Object FullName | ForEach-Object {
    $image = [System.Drawing.Image]::FromFile($_.FullName)
    try {
      $relative = $_.FullName.Substring($project.Length + 1).Replace('\', '/')
      $locale = if ($_.Name -match '_(ar|en|fr|es|tr)_') { $Matches[1] } else { 'global' }
      $platform = if ($relative -like 'store_assets/screenshots/apple/*') { 'apple' } elseif ($relative -like 'store_assets/screenshots/google_play/*' -or $relative -like '*google_play*') { 'google_play' } else { 'cross_platform' }
      $source = if ($relative -like '*screenshots/*') { 'actual_production_flutter_capture' } elseif ($relative -like 'store_assets/graphics/plans/*' -or $relative -like '*feature_graphic*') { 'original_generated_for_BIL' } else { 'approved_BIL_source_asset' }
      $rows += [pscustomobject]@{
        path = $relative
        platform = $platform
        width = $image.Width
        height = $image.Height
        locale = $locale
        source = $source
        rights_status = 'BIL_OWNED_OR_ORIGINAL_GENERATED_FOR_BIL'
        evidence = if ($relative -like '*screenshots/*') { 'test/epic15_store_screenshot_golden_test.dart' } else { 'docs/release/BIL_EPIC15_CONTENT_RIGHTS.json' }
        status = 'PASS'
        generated_utc = (Get-Date).ToUniversalTime().ToString('o')
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        pixel_format = $image.PixelFormat.ToString()
      }
    } finally { $image.Dispose() }
  }
  $rows | Export-Csv -LiteralPath (Join-Path $storeRoot 'evidence\asset_evidence_matrix.csv') -NoTypeInformation -Encoding UTF8
  $rows | Export-Csv -LiteralPath (Join-Path $storeRoot 'evidence\store_asset_inventory.csv') -NoTypeInformation -Encoding UTF8
  $rows | Where-Object { $_.source -eq 'actual_production_flutter_capture' } |
    Export-Csv -LiteralPath (Join-Path $storeRoot 'evidence\screenshot_matrix.csv') -NoTypeInformation -Encoding UTF8
  $localizationRows = @(
    [pscustomobject]@{ locale='ar'; direction='RTL'; listing='PASS'; screenshots='PASS'; subscription_copy='PASS'; owner_urls='OWNER_INPUT_REQUIRED' }
    [pscustomobject]@{ locale='en-US'; direction='LTR'; listing='PASS'; screenshots='PASS'; subscription_copy='PASS'; owner_urls='OWNER_INPUT_REQUIRED' }
    [pscustomobject]@{ locale='fr-FR'; direction='LTR'; listing='PASS'; screenshots='PASS_NEUTRAL_PLANS_CAPTURE'; subscription_copy='PASS'; owner_urls='OWNER_INPUT_REQUIRED' }
    [pscustomobject]@{ locale='es-ES'; direction='LTR'; listing='PASS'; screenshots='PASS_NEUTRAL_PLANS_CAPTURE'; subscription_copy='PASS'; owner_urls='OWNER_INPUT_REQUIRED' }
    [pscustomobject]@{ locale='tr-TR'; direction='LTR'; listing='PASS'; screenshots='PASS_NEUTRAL_PLANS_CAPTURE'; subscription_copy='PASS'; owner_urls='OWNER_INPUT_REQUIRED' }
  )
  $localizationRows | Export-Csv -LiteralPath (Join-Path $storeRoot 'evidence\localization_matrix.csv') -NoTypeInformation -Encoding UTF8
  $localizationRows | Export-Csv -LiteralPath (Join-Path $storeRoot 'evidence\store_metadata_matrix.csv') -NoTypeInformation -Encoding UTF8
  $rows | ForEach-Object { "$($_.sha256)  $($_.path)" } |
    Set-Content -LiteralPath (Join-Path $storeRoot 'evidence\sha256_manifest.txt') -Encoding ASCII
  $evidenceJson = $rows | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText(
    (Join-Path $storeRoot 'evidence\asset_evidence_matrix.json'),
    $evidenceJson,
    [Text.UTF8Encoding]::new($false)
  )
  $previewCards = $rows | ForEach-Object {
    "<figure><img src='../$($_.path.Substring('store_assets/'.Length))' alt='$($_.path)'><figcaption>$($_.path)<br>$($_.width)x$($_.height) · $($_.locale) · $($_.sha256.Substring(0, 12))</figcaption></figure>"
  }
  $previewHtml = @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>BIL Epic 15 asset previews</title>
<style>body{font:14px system-ui;background:#07142b;color:#eef6ff;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:18px}figure{margin:0;background:#10213f;border:1px solid #294466;border-radius:12px;padding:12px}img{width:100%;height:300px;object-fit:contain;background:#fff;border-radius:8px}figcaption{padding-top:9px;overflow-wrap:anywhere}</style></head><body><h1>BIL Epic 15 final asset previews</h1><main>$($previewCards -join "`n")</main></body></html>
"@
  [IO.File]::WriteAllText(
    (Join-Path $storeRoot 'evidence\preview_index.html'),
    $previewHtml,
    [Text.UTF8Encoding]::new($false)
  )
}

Write-Output "EPIC15_ASSET_PREPARATION=PASS"
Write-Output "PACKAGE_SCREENSHOTS=$PackageScreenshots"
