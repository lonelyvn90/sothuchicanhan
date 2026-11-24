# Lấy bảng giá xe máy mới từ trang chính thức của Honda và Yamaha Việt Nam -> xemay.json
# Ảnh không tải về: app hiện ảnh trực tiếp từ trang của hãng.
# Chạy: powershell -ExecutionPolicy Bypass -File update-xemay.ps1   (chạy được cả bằng pwsh)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36'
function Get-Html($u) { (Invoke-WebRequest $u -UseBasicParsing -UserAgent $ua -TimeoutSec 60).Content }
function Clean($s) { ([System.Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', ' ')) -replace '\s+', ' ').Trim() }
function Num($s) { [int64](($s -replace '[^\d]', '')) }

# ---------- Honda: bảng giá (mẫu xe -> phiên bản, màu, giá) ----------
$hondaUrl = 'https://www.honda.com.vn/xe-may/bang-gia'
$h = Get-Html $hondaUrl
$pat = '<td class="model_name table_pc"[^>]*>\s*<img src="(?<img>[^"]+)">\s*<br>\s*(?<model>[^<]+?)\s*</td>|<td class="model_name">(?<ver>.*?)</td>\s*<td class="color"[^>]*>(?<col>.*?)</td>\s*<td class="price price_pc">\s*(?<price>[\d\.]+)'
$honda = @(); $cur = $null
foreach ($m in [regex]::Matches($h, $pat, 'Singleline')) {
  if ($m.Groups['model'].Success) { $cur = [ordered]@{ name = (Clean $m.Groups['model'].Value); img = $m.Groups['img'].Value; variants = @() }; $honda += $cur }
  elseif ($cur) { $cur.variants += [ordered]@{ name = (Clean $m.Groups['ver'].Value); colors = (Clean $m.Groups['col'].Value) -replace ' / ', ', '; price = (Num $m.Groups['price'].Value) } }
}
foreach ($x in $honda) {
  $p = ($x.variants | ForEach-Object { $_.price } | Measure-Object -Minimum).Minimum
  $x.price = [int64]$p
  $x.cat = if ($x.name -match 'ADV|SH|Vario|Air Blade|Vision|LEAD|mode') { 'Tay ga' } elseif ($x.name -match 'CBR150|WINNER') { 'Côn tay' } elseif ($p -ge 100000000) { 'Phân khối lớn' } else { 'Xe số' }
}

# ---------- Yamaha: danh mục sản phẩm (loại xe -> mẫu, giá từ, ảnh) ----------
$yamahaUrl = 'https://yamaha-motor.com.vn/xe/'
$y = Get-Html $yamahaUrl
$pat2 = '<span class="textcate">(?<cat>[^<]+)<sup|<a\s+href="(?<link>[^"]+)"\s+class="submenu-item__link">.*?data-src="(?<img>[^"]+)".*?submenu-item__name">(?<name>[^<]+)</span>\s*<span class="submenu-item__price">(?<price>[^<]*)</span>'
$yamaha = @(); $seen = @{}; $cat = ''
foreach ($m in [regex]::Matches($y, $pat2, 'Singleline')) {
  if ($m.Groups['cat'].Success) { $cat = Clean $m.Groups['cat'].Value; continue }
  $link = $m.Groups['link'].Value; if ($seen[$link]) { continue }; $seen[$link] = 1
  $price = Num $m.Groups['price'].Value
  $yamaha += [ordered]@{ name = (Clean $m.Groups['name'].Value); cat = $cat; price = $price; img = $m.Groups['img'].Value; link = $link }
}

if ($honda.Count -lt 5 -or $yamaha.Count -lt 5) { throw "Lấy được quá ít mẫu xe (Honda $($honda.Count), Yamaha $($yamaha.Count)) - trang có thể đã đổi cấu trúc" }
$out = [ordered]@{ updated = (Get-Date -Format 'yyyy-MM-dd'); honda = [ordered]@{ url = $hondaUrl; items = $honda }; yamaha = [ordered]@{ url = $yamahaUrl; items = $yamaha } }
$json = $out | ConvertTo-Json -Depth 6 -Compress
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'xemay.json'), $json, (New-Object Text.UTF8Encoding($false)))
"Honda: $($honda.Count) mẫu, Yamaha: $($yamaha.Count) mẫu -> xemay.json"
