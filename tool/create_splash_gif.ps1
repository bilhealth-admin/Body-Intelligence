param(
  [string]$Frames = "test/goldens/premium_splash_frames",
  [string]$Output = "test/goldens/premium_splash_animation.gif"
)

$ffmpeg = "C:\Users\HP 1040 G8\AppData\Local\CapCut\Apps\9.0.0.3858\ffmpeg.exe"
if (Test-Path -LiteralPath $ffmpeg) {
  & $ffmpeg -y -framerate 3.0769 -i "$Frames/frame_%02d.png" `
    -vf "fps=12,scale=390:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" `
    -loop 0 $Output
  exit $LASTEXITCODE
}

Add-Type -AssemblyName System.Drawing
$framePaths = Get-ChildItem -LiteralPath $Frames -Filter "frame_*.png" |
  Sort-Object Name |
  Select-Object -ExpandProperty FullName
if ($framePaths.Count -eq 0) {
  throw "No splash frames found in $Frames"
}

$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Output))
$outputDirectory = [IO.Path]::GetDirectoryName($outputPath)
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

$gifCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object MimeType -eq "image/gif"
$encoder = [Drawing.Imaging.Encoder]::SaveFlag
$first = [Drawing.Image]::FromFile($framePaths[0])
try {
  $parameters = [Drawing.Imaging.EncoderParameters]::new(1)
  $parameters.Param[0] = [Drawing.Imaging.EncoderParameter]::new(
    $encoder,
    [long][Drawing.Imaging.EncoderValue]::MultiFrame
  )
  $first.Save($outputPath, $gifCodec, $parameters)

  foreach ($framePath in $framePaths[1..($framePaths.Count - 1)]) {
    $frame = [Drawing.Image]::FromFile($framePath)
    try {
      $parameters.Param[0] = [Drawing.Imaging.EncoderParameter]::new(
        $encoder,
        [long][Drawing.Imaging.EncoderValue]::FrameDimensionTime
      )
      $first.SaveAdd($frame, $parameters)
    } finally {
      $frame.Dispose()
    }
  }

  $parameters.Param[0] = [Drawing.Imaging.EncoderParameter]::new(
    $encoder,
    [long][Drawing.Imaging.EncoderValue]::Flush
  )
  $first.SaveAdd($parameters)
} finally {
  $first.Dispose()
}

Write-Output $outputPath
