# Docker/Rancher Cleanup and VHDX Shrink
# For Rancher Desktop on WSL2

#Requires -RunAsAdministrator

# Check if Docker is running
$dockerRunning = Get-Command docker -ErrorAction SilentlyContinue

if ($dockerRunning) {
    Write-Host "Docker is running. Cleaning up..." -ForegroundColor Cyan
    $confirm = Read-Host "Remove ALL unused containers, images, volumes? (y/N)"
    if ($confirm -eq 'y') {
        docker system prune -a -f --volumes
        Write-Host "✓ Docker cleaned" -ForegroundColor Green
    }
} else {
    Write-Host "Docker not running - skipping prune" -ForegroundColor Yellow
}

# Rancher Desktop VHDX
$rancherVhdx = "$env:LOCALAPPDATA\rancher-desktop\distro-data\ext4.vhdx"

if (-not (Test-Path $rancherVhdx)) {
    Write-Host "Rancher Desktop VHDX not found" -ForegroundColor Red
    exit
}

$sizeBefore = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
Write-Host "`nVHDX size: $sizeBefore GB" -ForegroundColor Cyan

$shrink = Read-Host "Shrink VHDX? (will stop Rancher & WSL) (y/N)"
if ($shrink -ne 'y') { exit }

# Stop everything
Write-Host "Stopping Rancher Desktop..." -ForegroundColor Yellow
Get-Process rancher-desktop -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3

Write-Host "Shutting down WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep 5

# Shrink using diskpart
Write-Host "Shrinking VHDX (may take several minutes)..." -ForegroundColor Yellow
$diskpartScript = @"
select vdisk file="$rancherVhdx"
attach vdisk readonly
compact vdisk
detach vdisk
"@

$diskpartScript | diskpart | Out-Null

$sizeAfter = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
$saved = $sizeBefore - $sizeAfter

Write-Host "`nBefore: $sizeBefore GB" -ForegroundColor Gray
Write-Host "After:  $sizeAfter GB" -ForegroundColor Green
Write-Host "Saved:  $saved GB" -ForegroundColor Green