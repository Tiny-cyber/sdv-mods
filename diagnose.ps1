$log = "D:\Steam\steamapps\common\Stardew Valley\ErrorLogs\SMAPI-latest.txt"
$mods = "D:\Steam\steamapps\common\Stardew Valley\Mods"

Write-Host "=== SMAPI Mod Diagnose ===" -ForegroundColor Cyan

if (Test-Path $log) {
    Write-Host "`n--- Skipped/Failed Mods ---" -ForegroundColor Yellow
    Get-Content $log | Where-Object { $_ -match "skipped|failed|couldn't|error|disabled" -and $_ -notmatch "ErrorHandler|ErrorLogs" } | Select-Object -First 30 | ForEach-Object { Write-Host $_ }

    Write-Host "`n--- Loaded Mod Count ---" -ForegroundColor Yellow
    $loaded = (Get-Content $log | Where-Object { $_ -match "loaded \d+ mods" })
    if ($loaded) { Write-Host $loaded }
} else {
    Write-Host "Log not found at $log" -ForegroundColor Red
}

Write-Host "`n--- Mods in Beauty Folder ---" -ForegroundColor Yellow
$beauty = Join-Path $mods "美化类"
if (Test-Path $beauty) {
    Get-ChildItem $beauty -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
} else {
    Write-Host "  No beauty folder found"
}

Write-Host "`n--- All Mod Folders ---" -ForegroundColor Yellow
Get-ChildItem $mods -Directory | ForEach-Object { Write-Host "  $($_.Name)" }

Write-Host "`nDone. Screenshot this and send to mian-ge." -ForegroundColor Cyan
Read-Host "Press Enter to close"
