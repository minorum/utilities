# Docker/Rancher Cleanup and VHDX Shrink
# For Rancher Desktop on WSL2

#Requires -RunAsAdministrator

function Test-DockerRunning {
    try {
        docker info 2>$null | Out-Null
        return $?
    }
    catch {
        return $false
    }
}

function Wait-ProcessStop {
    param([string]$ProcessName, [int]$TimeoutSeconds = 30)
    
    $elapsed = 0
    while ((Get-Process $ProcessName -ErrorAction SilentlyContinue) -and ($elapsed -lt $TimeoutSeconds)) {
        Start-Sleep -Seconds 1
        $elapsed++
    }
    
    if (Get-Process $ProcessName -ErrorAction SilentlyContinue) {
        Write-Host "⚠ $ProcessName didn't stop within $TimeoutSeconds seconds" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Check if Docker is running
if (Test-DockerRunning) {
    Write-Host "Docker is running. Cleaning up..." -ForegroundColor Cyan
    $confirm = Read-Host "Remove ALL unused containers, images, volumes? (y/N)"
    
    if ($confirm -eq 'y') {
        try {
            docker system prune -a -f --volumes
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Docker cleaned" -ForegroundColor Green
            } else {
                Write-Host "✗ Docker cleanup failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "✗ Docker cleanup error: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Docker not running - skipping prune" -ForegroundColor Yellow
}

# Rancher Desktop VHDX
$rancherVhdx = Join-Path $env:LOCALAPPDATA 'rancher-desktop\distro-data\ext4.vhdx'

if (-not (Test-Path $rancherVhdx)) {
    Write-Host "✗ Rancher Desktop VHDX not found at: $rancherVhdx" -ForegroundColor Red
    exit 1
}

$sizeBefore = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
Write-Host "VHDX size: $sizeBefore GB" -ForegroundColor Cyan

$shrink = Read-Host 'Shrink VHDX? (will stop Rancher & WSL) (y/N)'
if ($shrink -ne 'y') { 
    Write-Host "Cancelled" -ForegroundColor Gray
    exit 0 
}

# Stop everything
Write-Host "Stopping Rancher Desktop..." -ForegroundColor Yellow
$rancherProcess = Get-Process rancher-desktop -ErrorAction SilentlyContinue
if ($rancherProcess) {
    Stop-Process -Name rancher-desktop -Force
    if (-not (Wait-ProcessStop -ProcessName "rancher-desktop" -TimeoutSeconds 15)) {
        Write-Host "✗ Failed to stop Rancher Desktop" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Rancher Desktop stopped" -ForegroundColor Green
}

Write-Host "Shutting down WSL..." -ForegroundColor Yellow
wsl --shutdown

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ WSL shutdown failed" -ForegroundColor Red
    exit 1
}

# Wait for WSL to fully shutdown
Start-Sleep -Seconds 3
$wslState = wsl --list --running 2>$null
if ($wslState -match "rancher-desktop") {
    Write-Host "✗ WSL still running, cannot proceed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ WSL shutdown complete" -ForegroundColor Green

# Shrink using diskpart
Write-Host "Shrinking VHDX (may take several minutes)..." -ForegroundColor Yellow

$diskpartScript = @"
select vdisk file="$rancherVhdx"
attach vdisk readonly
compact vdisk
detach vdisk
"@

try {
    $diskpartOutput = $diskpartScript | diskpart 2>&1
    
    if ($diskpartOutput -match "DiskPart successfully") {
        Write-Host "✓ VHDX compacted successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠ Diskpart output:" -ForegroundColor Yellow
        $diskpartOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
}
catch {
    Write-Host "✗ Diskpart error: $_" -ForegroundColor Red
    exit 1
}

# Verify size reduction
Start-Sleep -Seconds 2
$sizeAfter = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
$saved = [math]::Round($sizeBefore - $sizeAfter, 2)

Write-Host ""
Write-Host "Before: $($sizeBefore) GB" -ForegroundColor Gray
Write-Host "After:  $($sizeAfter) GB" -ForegroundColor Green

if ($saved -gt 0) {
    Write-Host "Saved:  $($saved) GB" -ForegroundColor Green
} elseif ($saved -eq 0) {
    Write-Host "No space saved (VHDX already compact)" -ForegroundColor Yellow
} else {
    Write-Host "⚠ VHDX size increased (unexpected)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Done. You can now start Rancher Desktop." -ForegroundColor Cyan