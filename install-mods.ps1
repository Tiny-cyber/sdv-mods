$ProgressPreference = "SilentlyContinue"
$m = "D:\Steam\steamapps\common\Stardew Valley\Mods"

Write-Host "Finding sdv-mods-pack.zip..."
$pack = $null
$search = @(
    (Join-Path $env:USERPROFILE "Downloads"),
    (Join-Path $env:USERPROFILE "Desktop"),
    (Join-Path $env:USERPROFILE "Documents")
)
foreach ($s in $search) {
    $f = Get-ChildItem $s -Filter "sdv-mods-pack*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $pack = $f; break }
}

if (-not $pack) {
    Write-Host "Not found! Put sdv-mods-pack.zip in Downloads." -ForegroundColor Red
    Read-Host; exit 1
}
Write-Host "Found: $($pack.FullName)" -ForegroundColor Green

if (-not (Test-Path $m)) { New-Item -ItemType Directory -Path $m -Force | Out-Null }

$t = "$env:TEMP\sdv-pack"
if (Test-Path $t) { Remove-Item $t -Recurse -Force }
Expand-Archive $pack.FullName -DestinationPath $t -Force

$dir = Get-ChildItem $t -Directory | Select-Object -First 1
if (-not $dir) { $dir = Get-Item $t }

$count = 0
foreach ($f in (Get-ChildItem $dir.FullName -File)) {
    Write-Host "  $($f.Name)..." -NoNewline
    $d = "$env:TEMP\sdv-m"
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }

    if ($f.Extension -eq ".zip") {
        Expand-Archive $f.FullName -DestinationPath $d -Force
    } elseif ($f.Extension -eq ".rar") {
        New-Item $d -ItemType Directory -Force | Out-Null
        tar -xf $f.FullName -C $d 2>$null
    } else { Write-Host " skipped"; continue }

    $manifests = Get-ChildItem $d -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue
    foreach ($mf in $manifests) {
        $dest = Join-Path $m $mf.Directory.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $mf.Directory.FullName $dest -Recurse
        $count++
    }
    Write-Host " OK" -ForegroundColor Green
}

Remove-Item "$env:TEMP\sdv-m","$env:TEMP\sdv-pack" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n$count mods installed!" -ForegroundColor Cyan
Write-Host "Start game from Steam."
Read-Host "Press Enter to close"
