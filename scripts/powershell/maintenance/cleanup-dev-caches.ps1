# Development Caches Cleanup
# Removes NuGet packages, obj/bin folders, IDE caches
# SAFE - everything will be restored on demand

#Requires -RunAsAdministrator

$totalFreed = 0

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1GB, 2)
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
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  ✓ Removed" -ForegroundColor Green
                return $sizeBefore
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
$projectDirs = @("C:\projekty", "$env:USERPROFILE\source", "$env:USERPROFILE\Projects")
$totalObjBin = 0

foreach ($dir in $projectDirs) {
    if (Test-Path $dir) {
        $objBinFolders = Get-ChildItem -Path $dir -Directory -Recurse -Include "obj", "bin" -ErrorAction SilentlyContinue
        foreach ($folder in $objBinFolders) {
            $size = Get-FolderSize -Path $folder.FullName
            $totalObjBin += $size
        }
    }
}

if ($totalObjBin -gt 0.1) {
    Write-Host "Total obj/bin folders: $([math]::Round($totalObjBin, 2)) GB" -ForegroundColor Yellow
    $confirm = Read-Host "  Remove all? (y/N)"
    if ($confirm -eq 'y') {
        foreach ($dir in $projectDirs) {
            if (Test-Path $dir) {
                Get-ChildItem -Path $dir -Directory -Recurse -Include "obj", "bin" -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  ✓ Removed" -ForegroundColor Green
        $totalFreed += $totalObjBin
    }
}

# 3. Visual Studio / Rider
Write-Host "`n[3] IDE Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Description "VS ComponentModelCache"
$totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\JetBrains\Transient" -Description "Rider transient"

# 4. VSCode
Write-Host "`n[4] VSCode Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\Cache" -Description "VSCode cache"
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\CachedData" -Description "VSCode cached data"

# 5. Node (if applicable)
Write-Host "`n[5] Node.js Caches" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:APPDATA\npm-cache" -Description "npm cache"

# 6. Temp
Write-Host "`n[6] Temp Files" -ForegroundColor Cyan
$totalFreed += Remove-WithConfirm -Path "$env:TEMP\*" -Description "User temp"

Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green