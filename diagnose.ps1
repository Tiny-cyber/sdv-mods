$game = "D:\Steam\steamapps\common\Stardew Valley"
$mods = Join-Path $game "Mods"

Write-Host "=== SMAPI Mod Diagnose v2 ===" -ForegroundColor Cyan

# Find SMAPI log (check multiple locations)
$logPaths = @(
    (Join-Path $game "ErrorLogs\SMAPI-latest.txt"),
    (Join-Path $env:APPDATA "StardewValley\ErrorLogs\SMAPI-latest.txt"),
    (Join-Path $game "SMAPI-latest.txt")
)
$log = $null
foreach ($p in $logPaths) {
    if (Test-Path $p) { $log = $p; break }
}

if ($log) {
    Write-Host "`nLog: $log" -ForegroundColor Green
    Write-Host "`n--- Skipped/Failed ---" -ForegroundColor Yellow
    Get-Content $log | Where-Object { $_ -match "skipped|failed|couldn't|disabled|incompatible|duplicate" -and $_ -notmatch "ErrorHandler|error.wav" } | Select-Object -First 30 | ForEach-Object { Write-Host $_ }
    Write-Host "`n--- Mod Count ---" -ForegroundColor Yellow
    Get-Content $log | Where-Object { $_ -match "loaded \d+ mods|Found \d+ mods" } | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "`nSMAPI log not found. Searching..." -ForegroundColor Yellow
    Get-ChildItem $game -Recurse -Filter "SMAPI-latest.txt" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  Found: $($_.FullName)" }
    Get-ChildItem (Join-Path $env:APPDATA "StardewValley") -Recurse -Filter "SMAPI-latest.txt" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  Found: $($_.FullName)" }
}

# Check for duplicate ContentPatcher
Write-Host "`n--- ContentPatcher Check ---" -ForegroundColor Yellow
Get-ChildItem $mods -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue | ForEach-Object {
    $txt = Get-Content $_.FullName -ErrorAction SilentlyContinue
    if ($txt -match "ContentPatcher" -and $txt -match "EntryDll") {
        Write-Host "  ContentPatcher at: $($_.Directory.FullName)"
    }
}

# List our installed mods
Write-Host "`n--- Our Installed Mods ---" -ForegroundColor Yellow
$ours = @("Sebastian","Elliott","Shane","Pet Alex","Yandere","Spicy","EventRepeater","MailFramework","ContentPatcher")
Get-ChildItem $mods -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $name = $_.Name
    $ours | Where-Object { $name -match $_ }
} | ForEach-Object { Write-Host "  $($_.FullName.Replace($mods,''))" }

# Beauty folder detail
Write-Host "`n--- Beauty Folder Detail ---" -ForegroundColor Yellow
$beauty = Join-Path $mods "美化类"
if (Test-Path $beauty) {
    Get-ChildItem $beauty -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  $($_.FullName.Replace($beauty,''))"
    }
}

Write-Host "`nScreenshot this!" -ForegroundColor Cyan
Read-Host
