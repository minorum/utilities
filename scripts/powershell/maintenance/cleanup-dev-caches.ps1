# Development Caches Cleanup
# Removes NuGet packages, obj/bin folders, IDE caches
# SAFE - everything will be restored on demand

#Requires -RunAsAdministrator

$totalFreed = 0

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            return [math]::Round($size / 1GB, 2)
        } catch {
            return 0
        }
    }
    return 0
}

function Remove-WithConfirm {
    param(
        [string]$Path,
        [string]$Description
    )
    if (Test-Path $Path) {
        $sizeBefore = Get-FolderSize -Path $Path
        if ($sizeBefore -gt 0.01) {
            Write-Host "$Description`: $sizeBefore GB" -ForegroundColor Yellow
            $confirm = Read-Host "  Remove? (y/N)"
            if ($confirm -eq 'y') {
                try {
                    Write-Host "  Removing..." -NoNewline -ForegroundColor Yellow
                    Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                    Write-Host "`r  ✓ Removed      " -ForegroundColor Green
                    return $sizeBefore
                } catch {
                    Write-Host "`r  ✗ Failed: $_   " -ForegroundColor Red
                    return 0
                }
            }
        }
    }
    return 0
}

Write-Host "=== Development Caches Cleanup ===" -ForegroundColor Yellow
Write-Host "All items are safe to remove - they will be restored on demand`n" -ForegroundColor Gray

# 1. NuGet
Write-Host "[1] NuGet Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:USERPROFILE\.nuget\packages" -Description "Global packages"
$totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\NuGet\Cache" -Description "HTTP cache"

# 2. Build artifacts (obj/bin)
Write-Host "`n[2] Build Artifacts (obj/bin folders)" -ForegroundColor Cyan
$projectDirs = @("C:\projekty", "$env:USERPROFILE\source\repos", "$env:USERPROFILE\Projects")

Write-Host "  Scanning directories (this may take a moment)..." -ForegroundColor Gray

$allObjBinFolders = @()
foreach ($dir in $projectDirs) {
    if (Test-Path $dir) {
        Write-Host "    - $dir" -ForegroundColor DarkGray
        $found = @(Get-ChildItem -Path $dir -Directory -Recurse -Include "obj", "bin" -ErrorAction SilentlyContinue)
        $allObjBinFolders += $found
        Write-Host "      Found: $($found.Count) folders" -ForegroundColor DarkGray
    }
}

Write-Host "`n  Total found: $($allObjBinFolders.Count) folders" -ForegroundColor Green

if ($allObjBinFolders.Count -gt 0) {
    # Calculate total size
    Write-Host "  Calculating total size..." -ForegroundColor Gray
    $totalObjBinSize = 0
    $batches = [math]::Ceiling($allObjBinFolders.Count / 100)
    
    for ($i = 0; $i -lt $allObjBinFolders.Count; $i++) {
        $totalObjBinSize += Get-FolderSize -Path $allObjBinFolders[$i].FullName
        
        # Show progress every 100 folders
        if (($i + 1) % 100 -eq 0) {
            $percent = [math]::Round((($i + 1) / $allObjBinFolders.Count) * 100)
            Write-Host "`r  Progress: $percent% ($($i + 1)/$($allObjBinFolders.Count))" -NoNewline -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`r  Total size: $([math]::Round($totalObjBinSize, 2)) GB" + (" " * 30) -ForegroundColor Yellow
    $confirm = Read-Host "  Remove all? (y/N)"
    
    if ($confirm -eq 'y') {
        $removed = 0
        $failed = 0
        $total = $allObjBinFolders.Count
        
        Write-Host "  Removing folders..." -ForegroundColor Yellow
        for ($i = 0; $i -lt $total; $i++) {
            $percent = [math]::Round((($i + 1) / $total) * 100)
            
            # Progress bar
            $barLength = 40
            $filledLength = [math]::Round(($percent / 100) * $barLength)
            $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
            
            Write-Host "`r  [$bar] $percent% " -NoNewline -ForegroundColor Cyan
            
            try {
                Remove-Item -Path $allObjBinFolders[$i].FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $failed++
            }
        }
        
        Write-Host "`r  ✓ Removed $removed folders" + (" " * 60) -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  ⚠ Skipped $failed folders (files in use)" -ForegroundColor Yellow
        }
        $totalFreed += $totalObjBinSize
    }
} else {
    Write-Host "  No obj/bin folders found" -ForegroundColor Green
}

# 3. Visual Studio / Rider
Write-Host "`n[3] IDE Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Description "VS ComponentModelCache"
$totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\JetBrains\Transient" -Description "Rider transient"

# 4. VSCode
Write-Host "`n[4] VSCode Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\Cache" -Description "VSCode cache"
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\CachedData" -Description "VSCode cached data"

# 5. Node
Write-Host "`n[5] Node.js Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\npm-cache" -Description "npm cache"

# 6. Temp
Write-Host "`n[6] Temp Files" -ForegroundColor Cyan
$userTempSize = Get-FolderSize -Path $env:TEMP
if ($userTempSize -gt 0.1) {
    Write-Host "  User temp: $userTempSize GB" -ForegroundColor Yellow
    $confirm = Read-Host "  Remove? (y/N)"
    if ($confirm -eq 'y') {
        Write-Host "  Collecting items..." -ForegroundColor Gray
        $items = @(Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue)
        Write-Host "  Found $($items.Count) items" -ForegroundColor Gray
        
        $removed = 0
        $failed = 0
        $total = $items.Count
        
        Write-Host "  Removing..." -ForegroundColor Yellow
        for ($i = 0; $i -lt $total; $i++) {
            # Show progress every 50 items
            if ($i % 50 -eq 0 -or $i -eq $total - 1) {
                $percent = [math]::Round((($i + 1) / $total) * 100)
                $barLength = 40
                $filledLength = [math]::Round(($percent / 100) * $barLength)
                $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
                
                Write-Host "`r  [$bar] $percent% " -NoNewline -ForegroundColor Cyan
            }
            
            try {
                Remove-Item -Path $items[$i].FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $failed++
            }
        }
        
        Write-Host "`r  ✓ Removed $removed items" + (" " * 60) -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  ⚠ Skipped $failed items (in use)" -ForegroundColor Yellow
        }
        $totalFreed += $userTempSize
    }
}

Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green