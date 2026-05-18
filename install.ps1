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

# ---- Step 3: Install mods from sdv-mods-pack.zip ----
Write-Host "`n[3/3] Installing mods from sdv-mods-pack.zip..."

# Find the mod pack in Downloads
$downloads = Join-Path $env:USERPROFILE "Downloads"
$pack = Get-ChildItem $downloads -Filter "sdv-mods-pack.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pack) {
    # Also check Desktop and WeChat download locations
    $searchPaths = @($downloads, (Join-Path $env:USERPROFILE "Desktop"), (Join-Path $env:USERPROFILE "Documents\WeChat Files"))
    foreach ($sp in $searchPaths) {
        $pack = Get-ChildItem $sp -Filter "sdv-mods-pack.zip" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pack) { break }
    }
}
if (-not $pack) {
    Write-Host "  sdv-mods-pack.zip not found! Put it in Downloads folder." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
Write-Host "  Found: $($pack.FullName)"

# Extract the pack
$packDir = "$env:TEMP\sdv-mods-pack"
if (Test-Path $packDir) { Remove-Item $packDir -Recurse -Force }
Expand-Archive $pack.FullName -DestinationPath $packDir -Force

# Process each file in the pack
$installed = 0
$files = Get-ChildItem "$packDir\sdv-mods-pack" -File -ErrorAction SilentlyContinue
if (-not $files) { $files = Get-ChildItem $packDir -File }

foreach ($f in $files) {
    Write-Host "  Processing: $($f.Name)"
    $tempDir = "$env:TEMP\sdv-mod-temp"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }

    try {
        if ($f.Extension -eq ".zip") {
            Expand-Archive $f.FullName -DestinationPath $tempDir -Force
        } elseif ($f.Extension -eq ".rar") {
            # Try tar (Windows 10+) or fallback
            $tarResult = & tar -xf $f.FullName -C $tempDir 2>&1
            if ($LASTEXITCODE -ne 0) {
                # Create temp dir and try PowerShell COM
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                $shell = New-Object -ComObject Shell.Application
                $zip = $shell.NameSpace($f.FullName)
                if ($zip) {
                    $dest = $shell.NameSpace($tempDir)
                    $dest.CopyHere($zip.Items(), 0x14)
                } else {
                    Write-Host "    Cannot extract .rar - skipping (install 7-Zip for .rar support)" -ForegroundColor Yellow
                    continue
                }
            }
        }

        # Find manifest.json files and install each mod
        $manifests = Get-ChildItem $tempDir -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue
        if ($manifests.Count -gt 0) {
            foreach ($mf in $manifests) {
                $modFolder = $mf.Directory
                $destFolder = Join-Path $modsPath $modFolder.Name
                if (Test-Path $destFolder) { Remove-Item $destFolder -Recurse -Force }
                Copy-Item $modFolder.FullName $destFolder -Recurse
                $json = Get-Content $mf.FullName -Raw | ConvertFrom-Json
                Write-Host "    -> $($json.Name) v$($json.Version)" -ForegroundColor Green
                $installed++
            }
        } else {
            # No manifest - copy all contents directly to Mods
            $items = Get-ChildItem $tempDir -Directory
            foreach ($item in $items) {
                $destFolder = Join-Path $modsPath $item.Name
                if (Test-Path $destFolder) { Remove-Item $destFolder -Recurse -Force }
                Copy-Item $item.FullName $destFolder -Recurse
                Write-Host "    -> $($item.Name) (copied)" -ForegroundColor Green
                $installed++
            }
        }
    } catch {
        Write-Host "    -> Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Cleanup
if (Test-Path "$env:TEMP\sdv-mod-temp") { Remove-Item "$env:TEMP\sdv-mod-temp" -Recurse -Force }
if (Test-Path $packDir) { Remove-Item $packDir -Recurse -Force }

Write-Host "`n=============================="
Write-Host "  Done! $installed mods installed."
Write-Host "==============================`n"
Write-Host "Installed mods:"
Get-ChildItem $modsPath -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host "`nStart the game through Steam to play with mods!"
Write-Host ""
Read-Host "Press Enter to close"
