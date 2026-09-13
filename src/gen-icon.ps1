Add-Type -AssemblyName System.Drawing

$sz = 32
$bmp = New-Object System.Drawing.Bitmap($sz, $sz)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)

$dark = [System.Drawing.Color]::FromArgb(255, 45, 60, 95)
$screen = [System.Drawing.Color]::FromArgb(255, 85, 145, 210)
$highlight = [System.Drawing.Color]::FromArgb(60, 180, 220, 255)
$stand = [System.Drawing.Color]::FromArgb(255, 55, 70, 100)

$g.FillRectangle((New-Object System.Drawing.SolidBrush($dark)), 3, 4, 26, 18)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($screen)), 5, 6, 22, 14)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($highlight)), 6, 7, 9, 5)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($stand)), 13, 22, 6, 3)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($stand)), 9, 25, 14, 3)
$g.DrawRectangle((New-Object System.Drawing.Pen($dark, 1)), 3, 4, 25, 17)
$g.Dispose()

$pngMs = New-Object System.IO.MemoryStream
$bmp.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
$pngData = $pngMs.ToArray()
$pngMs.Dispose()
$bmp.Dispose()

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([Int16]0)
$bw.Write([Int16]1)
$bw.Write([Int16]1)
$bw.Write([Byte]32)
$bw.Write([Byte]32)
$bw.Write([Byte]0)
$bw.Write([Byte]0)
$bw.Write([Int16]1)
$bw.Write([Int16]32)
$bw.Write([Int32]$pngData.Length)
$bw.Write([Int32]22)
$bw.Write($pngData)
$bw.Flush()

[System.IO.File]::WriteAllBytes("$PSScriptRoot\app.ico", $ms.ToArray())
$ms.Dispose()
