# Đóng gói Sổ Thu Chi thành thư mục so-thu-chi-app chỉ gồm 6 file (không có thư mục con),
# logo được thu nhỏ và gộp thẳng vào index.html để upload lên GitHub cho dễ.
# Chạy: powershell -ExecutionPolicy Bypass -File build-app.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing

function Get-LogoDataUri($path) {
  $ext = [IO.Path]::GetExtension($path).ToLower()
  if ($ext -eq '.ico') { return 'data:image/x-icon;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) }
  $img = [Drawing.Image]::FromFile($path)
  try {
    $scale = [Math]::Min(1.0, [Math]::Min(240.0 / $img.Width, 120.0 / $img.Height))
    $w = [Math]::Max(1, [int]($img.Width * $scale)); $h = [Math]::Max(1, [int]($img.Height * $scale))
    $bmp = New-Object Drawing.Bitmap $w, $h
    $g = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
    $g.DrawImage($img, 0, 0, $w, $h); $g.Dispose()
    $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    return 'data:image/png;base64,' + [Convert]::ToBase64String($ms.ToArray())
  } finally { $img.Dispose() }
}

$entries = foreach ($f in Get-ChildItem logos -File) { '"' + $f.BaseName + '":"' + (Get-LogoDataUri $f.FullName) + '"' }
$script = '<script>window.LOGO_DATA={' + ($entries -join ',') + '};</script>'

$html = [IO.File]::ReadAllText("$PWD\so-thu-chi.html", [Text.Encoding]::UTF8)
$i = $html.IndexOf('<script>')
$html = $html.Substring(0, $i) + $script + "`n" + $html.Substring($i)

# index.html (bản dùng trên GitHub Pages) nằm ở gốc kho, cạnh sw.js, manifest và icon.
[IO.File]::WriteAllText("$PWD\index.html", $html, (New-Object Text.UTF8Encoding($false)))
Get-ChildItem index.html, sw.js, manifest.webmanifest, icon-192.png, icon-512.png, apple-touch-icon.png |
  ForEach-Object { '{0,-24} {1,8} KB' -f $_.Name, [Math]::Round($_.Length / 1KB) }
