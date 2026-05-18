$ProgressPreference = "SilentlyContinue"
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "Setting up SSH tunnel..."

# 1. Install OpenSSH Server
Write-Host "[1/3] Installing SSH..."
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd) {
    Write-Host "  SSH already installed"
} else {
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    } catch {
        Write-Host "  Built-in install failed, downloading..."
        Invoke-WebRequest -Uri "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.8.1.0p1-Preview/OpenSSH-Win64-v9.8.1.0.msi" -OutFile "$env:TEMP\openssh.msi" -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\openssh.msi /qn" -Wait
    }
}
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
Write-Host "  SSH OK" -ForegroundColor Green

# 2. Add public key
Write-Host "[2/3] Adding SSH key..."
$key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICmtCGpspbS4qb632U7cUlO0UJXqnZGJZMySVYtV1gPI tinypity@TinyPitydeMac-mini.local"
New-Item -ItemType Directory -Path "C:\ProgramData\ssh" -Force | Out-Null
$key | Out-File -Encoding utf8 "C:\ProgramData\ssh\administrators_authorized_keys" -Force
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F" | Out-Null
Write-Host "  Key OK" -ForegroundColor Green

# 3. Open firewall
try {
    $rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
} catch {}

# 4. Download and run bore tunnel
Write-Host "[3/3] Starting tunnel..."
$bore = "$env:TEMP\bore.exe"
if (-not (Test-Path $bore)) {
    Invoke-WebRequest -Uri "https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-pc-windows-msvc.exe" -OutFile $bore -UseBasicParsing
}
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Tunnel starting! Tell mian-ge the"
Write-Host "  address shown below (bore.pub:XXXXX)"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
& $bore local 22 --to bore.pub
