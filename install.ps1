# Stardew Valley Mod Installer
# Usage: irm https://raw.githubusercontent.com/Tiny-cyber/sdv-mods/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "=============================="
Write-Host "  Stardew Valley Mod Installer"
Write-Host "=============================="
Write-Host ""

# ---- Step 1: Find game ----
Write-Host "[1/4] Finding Stardew Valley..."
$gamePath = $null
$tryPaths = @(
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\Stardew Valley",
    "$env:ProgramFiles\Steam\steamapps\common\Stardew Valley"
)
# Search all Steam libraries
$libFile = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
if (Test-Path $libFile) {
    [regex]::Matches((Get-Content $libFile -Raw), '"path"\s+"([^"]+)"') | ForEach-Object {
        $tryPaths += "$($_.Groups[1].Value)\steamapps\common\Stardew Valley"
    }
}
# Also check common drive roots
"C","D","E","F" | ForEach-Object {
    $tryPaths += "${_}:\Steam\steamapps\common\Stardew Valley"
    $tryPaths += "${_}:\SteamLibrary\steamapps\common\Stardew Valley"
    $tryPaths += "${_}:\Games\Steam\steamapps\common\Stardew Valley"
    $tryPaths += "${_}:\Program Files (x86)\Steam\steamapps\common\Stardew Valley"
}

foreach ($p in ($tryPaths | Select-Object -Unique)) {
    if (Test-Path "$p\Stardew Valley.exe") { $gamePath = $p; break }
}

if (-not $gamePath) {
    $gamePath = Read-Host "Auto-detect failed. Enter game folder path"
    if (-not (Test-Path "$gamePath\Stardew Valley.exe")) {
        Write-Host "Invalid path!"; Read-Host "Press Enter to exit"; exit 1
    }
}
Write-Host "  Found: $gamePath" -ForegroundColor Green

# ---- Step 2: Install SMAPI ----
Write-Host "`n[2/4] Installing SMAPI..."
$smapiZip = "$env:TEMP\smapi.zip"
$smapiDir = "$env:TEMP\smapi-installer"
Invoke-WebRequest -Uri "https://github.com/Pathoschild/SMAPI/releases/download/4.5.2/SMAPI-4.5.2-installer.zip" -OutFile $smapiZip -UseBasicParsing
if (Test-Path $smapiDir) { Remove-Item $smapiDir -Recurse -Force }
Expand-Archive $smapiZip -DestinationPath $smapiDir -Force

$installerExe = Get-ChildItem $smapiDir -Recurse -Filter "SMAPI.Installer.exe" | Select-Object -First 1
if ($installerExe) {
    & $installerExe.FullName --install --game-path $gamePath 2>$null
    Write-Host "  SMAPI installed!" -ForegroundColor Green
} else {
    # Fallback: try install.dat
    $installDat = Get-ChildItem $smapiDir -Recurse -Filter "install.dat" | Select-Object -First 1
    if ($installDat) {
        $exePath = $installDat.FullName -replace "\.dat$", ".exe"
        Copy-Item $installDat.FullName $exePath
        & $exePath --install --game-path $gamePath 2>$null
        Write-Host "  SMAPI installed!" -ForegroundColor Green
    } else {
        Write-Host "  Auto-install failed. Opening folder for manual install..." -ForegroundColor Yellow
        $batFile = Get-ChildItem $smapiDir -Recurse -Filter "install on Windows.bat" | Select-Object -First 1
        if ($batFile) { explorer $batFile.Directory.FullName }
        Write-Host "  Double-click 'install on Windows.bat' and choose option 1"
        Read-Host "  Press Enter after SMAPI is installed"
    }
}

# Ensure Mods folder
$modsPath = Join-Path $gamePath "Mods"
if (-not (Test-Path $modsPath)) { New-Item -ItemType Directory -Path $modsPath -Force | Out-Null }

# Save path for step 4
$gamePath | Out-File "$env:TEMP\sdv-path.txt" -Encoding utf8

# ---- Step 3: Open mod download pages ----
Write-Host "`n[3/4] Opening mod pages in browser..."
Write-Host "  Log in to Nexus Mods, then click 'Manual' -> 'Slow Download' on each page.`n"

$mods = @(
    @{id=1915;  name="Content Patcher (required base)"},
    @{id=26926; name="Sebastian After Marriage R18"},
    @{id=26318; name="Sebastian 18+"},
    @{id=25040; name="Sebastian Yandere R18"},
    @{id=12393; name="Elliott Yandere R18"},
    @{id=26010; name="Elliott Right Position"},
    @{id=24456; name="Elliott Exclusive Story"},
    @{id=24988; name="Elliott SM"},
    @{id=17464; name="Shane Right Position"}
)

foreach ($mod in $mods) {
    Write-Host "  Opening: $($mod.name)"
    Start-Process "https://www.nexusmods.com/stardewvalley/mods/$($mod.id)?tab=files"
    Start-Sleep -Milliseconds 800
}

Write-Host "`n  9 tabs opened. Download all of them now." -ForegroundColor Cyan
Write-Host "  After ALL downloads finish, press Enter here.`n"
Read-Host "Press Enter when all 9 mods are downloaded"

# ---- Step 4: Install downloaded mods ----
Write-Host "[4/4] Installing downloaded mods..."
$downloads = Join-Path $env:USERPROFILE "Downloads"
$zips = Get-ChildItem $downloads -Filter "*.zip" | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } | Sort-Object LastWriteTime -Descending

if ($zips.Count -eq 0) {
    # Also try .7z and .rar
    $zips = Get-ChildItem $downloads -Filter "*.7z" | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) }
}

$installed = 0
foreach ($z in $zips) {
    try {
        $tempDir = "$env:TEMP\sdv-mod-temp"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        Expand-Archive $z.FullName -DestinationPath $tempDir -Force

        $manifests = Get-ChildItem $tempDir -Recurse -Filter "manifest.json"
        foreach ($mf in $manifests) {
            $modFolder = $mf.Directory
            $destFolder = Join-Path $modsPath $modFolder.Name
            if (Test-Path $destFolder) { Remove-Item $destFolder -Recurse -Force }
            Copy-Item $modFolder.FullName $destFolder -Recurse
            $json = Get-Content $mf.FullName -Raw | ConvertFrom-Json
            Write-Host "  Installed: $($json.Name) v$($json.Version)" -ForegroundColor Green
            $installed++
        }
    } catch {
        Write-Host "  Skipped: $($z.Name) - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (Test-Path "$env:TEMP\sdv-mod-temp") { Remove-Item "$env:TEMP\sdv-mod-temp" -Recurse -Force }

Write-Host "`n=============================="
Write-Host "  Done! $installed mods installed."
Write-Host "==============================`n"
Write-Host "Installed mods:"
Get-ChildItem $modsPath -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host "`nStart the game through Steam to play with mods!"
Write-Host ""
Read-Host "Press Enter to close"
