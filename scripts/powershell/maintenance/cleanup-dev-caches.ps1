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

function Show-Spinner {
    param([string]$Message)
    $spinChars = @('|', '/', '-', '\')
    $spin = $spinChars[$script:spinIndex % 4]
    $script:spinIndex++
    Write-Host "`r  $Message $spin" -NoNewline -ForegroundColor Gray
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
                    Write-Host "`r  ✓ Removed                    " -ForegroundColor Green
                    return $sizeBefore
                } catch {
                    Write-Host "`r  ✗ Failed: $_                 " -ForegroundColor Red
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

$script:spinIndex = 0
Write-Host "  Scanning for obj/bin folders..." -NoNewline -ForegroundColor Gray

$allObjBinFolders = @()
foreach ($dir in $projectDirs) {
    if (Test-Path $dir) {
        $found = Get-ChildItem -Path $dir -Directory -Recurse -Include "obj", "bin" -ErrorAction SilentlyContinue | ForEach-Object {
            Show-Spinner "Scanning... found $($allObjBinFolders.Count)"
            $_
        }
        $allObjBinFolders += @($found)
    }
}

Write-Host "`r  ✓ Found $($allObjBinFolders.Count) folders                           " -ForegroundColor Green

if ($allObjBinFolders.Count -gt 0) {
    # Calculate total size with progress
    Write-Host "  Calculating size..." -NoNewline -ForegroundColor Gray
    $script:spinIndex = 0
    $totalObjBinSize = 0
    $processed = 0
    
    foreach ($folder in $allObjBinFolders) {
        $totalObjBinSize += Get-FolderSize -Path $folder.FullName
        $processed++
        if ($processed % 10 -eq 0) {
            Show-Spinner "Calculating... $processed/$($allObjBinFolders.Count)"
        }
    }
    
    Write-Host "`r  ✓ Total: $([math]::Round($totalObjBinSize, 2)) GB in $($allObjBinFolders.Count) folders                " -ForegroundColor Yellow
    $confirm = Read-Host "  Remove all? (y/N)"
    
    if ($confirm -eq 'y') {
        $removed = 0
        $failed = 0
        $total = $allObjBinFolders.Count
        
        foreach ($folder in $allObjBinFolders) {
            $current = $removed + $failed + 1
            $percent = [math]::Round(($current / $total) * 100)
            
            # Progress bar
            $barLength = 30
            $filledLength = [math]::Round(($percent / 100) * $barLength)
            $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
            
            Write-Host "`r  [$bar] $percent% ($current/$total)" -NoNewline -ForegroundColor Cyan
            
            try {
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $failed++
            }
        }
        
        Write-Host "`r  ✓ Removed $removed folders" + (" " * 50) -ForegroundColor Green
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
        Write-Host "  Collecting items..." -NoNewline -ForegroundColor Gray
        $items = @(Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue)
        Write-Host "`r  Found $($items.Count) items" -ForegroundColor Gray
        
        $removed = 0
        $failed = 0
        $total = $items.Count
        
        foreach ($item in $items) {
            $current = $removed + $failed + 1
            $percent = [math]::Round(($current / $total) * 100)
            
            $barLength = 30
            $filledLength = [math]::Round(($percent / 100) * $barLength)
            $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
            
            Write-Host "`r  [$bar] $percent% ($current/$total)" -NoNewline -ForegroundColor Cyan
            
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $failed++
            }
        }
        
        Write-Host "`r  ✓ Removed $removed items" + (" " * 50) -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  ⚠ Skipped $failed items (in use)" -ForegroundColor Yellow
        }
        $totalFreed += $userTempSize
    }
}

Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green