param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$coveragePath = Join-Path $ProjectRoot 'artifacts\release\visual_closure\reference\visual_reference_truth_matrix.csv'
$outputRoot = Join-Path $ProjectRoot 'artifacts\release\visual_closure\comparisons'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$rows = Import-Csv -LiteralPath $coveragePath
$pageSize = 20
$cellWidth = 420
$imageHeight = 320
$cellHeight = 390
$columns = 2
$rowsPerSheet = [math]::Ceiling($pageSize / $columns)
$font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Regular)
$fontBold = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)
$brush = [Drawing.Brushes]::Black
$mutedBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(80, 80, 80))
$background = [Drawing.Color]::White

function Draw-FittedImage {
  param(
    [Drawing.Graphics]$Graphics,
    [Drawing.Image]$Image,
    [Drawing.Rectangle]$Bounds
  )
  $scale = [math]::Min($Bounds.Width / $Image.Width, $Bounds.Height / $Image.Height)
  $width = [int]($Image.Width * $scale)
  $height = [int]($Image.Height * $scale)
  $x = $Bounds.X + [int](($Bounds.Width - $width) / 2)
  $y = $Bounds.Y + [int](($Bounds.Height - $height) / 2)
  $Graphics.DrawImage($Image, $x, $y, $width, $height)
}

for ($offset = 0; $offset -lt $rows.Count; $offset += $pageSize) {
  $batch = @($rows | Select-Object -Skip $offset -First $pageSize)
  $bitmap = New-Object Drawing.Bitmap ($cellWidth * $columns), ($cellHeight * $rowsPerSheet)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear($background)
  $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  for ($index = 0; $index -lt $batch.Count; $index++) {
    $entry = $batch[$index]
    $column = $index % $columns
    $row = [math]::Floor($index / $columns)
    $x = $column * $cellWidth
    $y = $row * $cellHeight
    $halfWidth = [int]($cellWidth / 2)

    $referencePath = Join-Path $ProjectRoot "artifacts\release\visual_closure\reference\previews\IMG_$($entry.reference).jpg"
    $evidenceRelative = $entry.evidence_after
    $evidencePath = Join-Path $ProjectRoot ($evidenceRelative -replace '/', '\')

    $graphics.DrawString("$($entry.reference) • $($entry.screen)", $fontBold, $brush, $x + 8, $y + 5)
    $graphics.DrawString('REFERENCE', $font, $mutedBrush, $x + 8, $y + 28)
    $graphics.DrawString('CURRENT PRODUCTION', $font, $mutedBrush, $x + $halfWidth + 8, $y + 28)

    if (Test-Path -LiteralPath $referencePath) {
      $reference = [Drawing.Image]::FromFile($referencePath)
      try {
        Draw-FittedImage -Graphics $graphics -Image $reference -Bounds ([Drawing.Rectangle]::new($x + 6, $y + 50, $halfWidth - 12, $imageHeight))
      } finally {
        $reference.Dispose()
      }
    }
    if (Test-Path -LiteralPath $evidencePath) {
      $evidence = [Drawing.Image]::FromFile($evidencePath)
      try {
        Draw-FittedImage -Graphics $graphics -Image $evidence -Bounds ([Drawing.Rectangle]::new($x + $halfWidth + 6, $y + 50, $halfWidth - 12, $imageHeight))
      } finally {
        $evidence.Dispose()
      }
    } else {
      $graphics.DrawString('MISSING EVIDENCE', $fontBold, [Drawing.Brushes]::Red, $x + $halfWidth + 25, $y + 190)
    }
    $graphics.DrawRectangle([Drawing.Pens]::LightGray, $x, $y, $cellWidth - 1, $cellHeight - 1)
  }

  $sheetNumber = [int]($offset / $pageSize) + 1
  $path = Join-Path $outputRoot ('visual_comparison_{0:D2}.jpg' -f $sheetNumber)
  $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Jpeg)
  $graphics.Dispose()
  $bitmap.Dispose()
}

$font.Dispose()
$fontBold.Dispose()
$mutedBrush.Dispose()
Write-Output "VISUAL_COMPARISON_SHEETS=$([math]::Ceiling($rows.Count / $pageSize))"
Write-Output "VISUAL_REFERENCE_ROWS=$($rows.Count)"
Write-Output "OUTPUT_ROOT=$outputRoot"
