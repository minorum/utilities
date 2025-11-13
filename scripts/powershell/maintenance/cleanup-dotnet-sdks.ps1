# .NET SDK Cleanup and Update Script
# Shows installed SDKs, recommends what to remove, and helps update

#Requires -RunAsAdministrator

Write-Host "=== .NET SDK Manager ===" -ForegroundColor Yellow
Write-Host ""

# Get installed SDKs
$installedSdks = dotnet --list-sdks | ForEach-Object {
    if ($_ -match '^(\d+\.\d+\.\d+)\s+\[(.+)\]$') {
        [PSCustomObject]@{
            Version = $matches[1]
            Path = $matches[2]
            Major = [int]($matches[1] -split '\.')[0]
            IsLTS = $false
        }
    }
}

# Mark LTS versions
$installedSdks | Where-Object { $_.Major -in @(6,8) } | ForEach-Object { $_.IsLTS = $true }

# Check for updates via winget
Write-Host "Checking for updates..." -ForegroundColor Cyan
$wingetList = winget list --id Microsoft.DotNet.SDK --accept-source-agreements 2>$null | Out-String

# Group by major version
$grouped = $installedSdks | Group-Object -Property Major | Sort-Object Name

Write-Host "`nInstalled SDKs by version:" -ForegroundColor Yellow
foreach ($group in $grouped) {
    $majorVersion = $group.Name
    $versions = $group.Group | Sort-Object Version -Descending
    $latest = $versions[0]
    $older = $versions | Select-Object -Skip 1
    
    $ltsTag = if ($latest.IsLTS) { " [LTS]" } else { "" }
    $eolTag = if ($majorVersion -in @(6,7)) { " [EOL]" } else { "" }
    
    Write-Host "`n.NET $majorVersion$ltsTag$eolTag" -ForegroundColor Cyan
    Write-Host "  Latest: $($latest.Version)" -ForegroundColor Green
    
    if ($older.Count -gt 0) {
        Write-Host "  Older versions:" -ForegroundColor Yellow
        foreach ($old in $older) {
            Write-Host "    - $($old.Version)" -ForegroundColor Gray
        }
    }
}

# Recommendations
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Yellow

# EOL versions
$eolVersions = $installedSdks | Where-Object { $_.Major -in @(6,7) }
if ($eolVersions) {
    Write-Host "`n❌ Remove (End of Life):" -ForegroundColor Red
    Write-Host "   .NET 6 - Support ended November 2024" -ForegroundColor Gray
    Write-Host "   .NET 7 - Support ended May 2024" -ForegroundColor Gray
    foreach ($sdk in $eolVersions) {
        Write-Host "   winget uninstall --id Microsoft.DotNet.SDK.$($sdk.Major) --version $($sdk.Version)" -ForegroundColor DarkGray
    }
}

# Duplicate versions
Write-Host "`n⚠️  Keep only latest patch version per major:" -ForegroundColor Yellow
foreach ($group in $grouped | Where-Object { $_.Group.Count -gt 1 }) {
    $majorVersion = $group.Name
    $versions = $group.Group | Sort-Object Version -Descending
    $toRemove = $versions | Select-Object -Skip 1
    
    if ($toRemove) {
        Write-Host "   .NET $majorVersion - Remove older patches:" -ForegroundColor Gray
        foreach ($sdk in $toRemove) {
            Write-Host "   winget uninstall --id Microsoft.DotNet.SDK.$($sdk.Major) --version $($sdk.Version)" -ForegroundColor DarkGray
        }
    }
}

# What to keep
Write-Host "`n✅ Recommended to keep:" -ForegroundColor Green
$toKeep = $grouped | ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 }
foreach ($sdk in $toKeep | Where-Object { $_.Major -notin @(6,7) }) {
    $ltsTag = if ($sdk.IsLTS) { " [LTS]" } else { "" }
    Write-Host "   .NET $($sdk.Major)$ltsTag - $($sdk.Version)" -ForegroundColor Gray
}

# Interactive removal
Write-Host "`n=== ACTIONS ===" -ForegroundColor Yellow
$remove6and7 = Read-Host "Remove all .NET 6 and 7 SDKs? (y/N)"
if ($remove6and7 -eq 'y') {
    foreach ($sdk in $eolVersions) {
        Write-Host "Removing .NET $($sdk.Version)..." -ForegroundColor Yellow
        winget uninstall --id "Microsoft.DotNet.SDK.$($sdk.Major)" --version $sdk.Version --silent
    }
    Write-Host "✓ EOL versions removed" -ForegroundColor Green
}

$removeOlder = Read-Host "Remove older patch versions (keep only latest per major)? (y/N)"
if ($removeOlder -eq 'y') {
    foreach ($group in $grouped | Where-Object { $_.Group.Count -gt 1 -and $_.Name -notin @(6,7) }) {
        $versions = $group.Group | Sort-Object Version -Descending
        $toRemove = $versions | Select-Object -Skip 1
        
        foreach ($sdk in $toRemove) {
            Write-Host "Removing .NET $($sdk.Version)..." -ForegroundColor Yellow
            winget uninstall --id "Microsoft.DotNet.SDK.$($sdk.Major)" --version $sdk.Version --silent
        }
    }
    Write-Host "✓ Older patches removed" -ForegroundColor Green
}

Write-Host "`nDone! Run 'dotnet --list-sdks' to verify." -ForegroundColor Cyan