# ממיר את צילומי integration_test/installer_screenshots_test.dart לתמונות המתקין,
# בגודל התמונות הקיימות. עם -PreviewDir נשמרות גם before-N / after-N / full-N להשוואה.
param(
  [Parameter(Mandatory = $true)] [string] $ShotsDir,
  [string] $InstallerDir = (Join-Path $PSScriptRoot '..\..\installer'),
  [string] $PreviewDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$png = [System.Drawing.Imaging.ImageFormat]::Png
if ($PreviewDir) { New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null }

foreach ($n in 1..4) {
  $shotPath = (Resolve-Path (Join-Path $ShotsDir "feature$n.png")).Path
  $bmpPath = (Resolve-Path (Join-Path $InstallerDir "feature$n.bmp")).Path

  $old = [System.Drawing.Bitmap]::new($bmpPath)
  $width = $old.Width
  $height = $old.Height
  if ($PreviewDir) { $old.Save((Join-Path $PreviewDir "before-$n.png"), $png) }
  $old.Dispose()

  $shot = [System.Drawing.Image]::FromFile($shotPath)
  $out = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($out)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  # בלי TileFlipXY ההקטנה מושכת פס כהה לאורך השוליים.
  $attrs = [System.Drawing.Imaging.ImageAttributes]::new()
  $attrs.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
  $g.DrawImage($shot, [System.Drawing.Rectangle]::new(0, 0, $width, $height),
    0, 0, $shot.Width, $shot.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
  $attrs.Dispose()
  $g.Dispose()
  $shot.Dispose()

  $out.Save($bmpPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
  if ($PreviewDir) {
    $out.Save((Join-Path $PreviewDir "after-$n.png"), $png)
    Copy-Item $shotPath (Join-Path $PreviewDir "full-$n.png")
  }
  $out.Dispose()
  Write-Host "feature$n.bmp -> ${width}x${height}"
}
