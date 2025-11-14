# Maintenance Scripts TUI Menu
# Central entrypoint for all maintenance scripts
# Allows enabling/disabling specific steps and configuring options

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ========================= HELPER FUNCTIONS =========================

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║      " -NoNewline -ForegroundColor Cyan
    Write-Host "Windows Maintenance Scripts - TUI Menu" -NoNewline -ForegroundColor Yellow
    Write-Host "               ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-MenuItem {
    param(
        [string]$Index,
        [string]$Text,
        [bool]$Enabled = $true,
        [int]$Indent = 2
    )

    $checkbox = if ($Enabled) { "[✓]" } else { "[ ]" }
    $color = if ($Enabled) { "Green" } else { "DarkGray" }
    $prefix = " " * $Indent

    Write-Host "$prefix$Index. " -NoNewline -ForegroundColor White
    Write-Host "$checkbox " -NoNewline -ForegroundColor $color
    Write-Host $Text -ForegroundColor White
}

function Get-UserChoice {
    param(
        [string]$Prompt = "Enter choice",
        [string[]]$ValidChoices = @()
    )

    Write-Host ""
    if ($ValidChoices.Count -gt 0) {
        $validStr = $ValidChoices -join ", "
        Write-Host "  $Prompt [$validStr]: " -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host "  $Prompt: " -NoNewline -ForegroundColor Yellow
    }

    $choice = Read-Host
    return $choice.Trim()
}

function Select-Directory {
    param(
        [string]$Title = "Select Directory",
        [string]$InitialDirectory = $env:USERPROFILE
    )

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  Current: " -NoNewline -ForegroundColor Gray
    Write-Host $InitialDirectory -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Use current directory" -ForegroundColor White
    Write-Host "  2. Enter custom path" -ForegroundColor White
    Write-Host "  3. Browse common locations" -ForegroundColor White

    $choice = Get-UserChoice -Prompt "Select option" -ValidChoices @("1", "2", "3")

    switch ($choice) {
        "1" {
            return $InitialDirectory
        }
        "2" {
            $customPath = Get-UserChoice -Prompt "Enter full path"
            if (Test-Path $customPath) {
                return $customPath
            } else {
                Write-Host "  Invalid path, using default" -ForegroundColor Red
                Start-Sleep -Seconds 1
                return $InitialDirectory
            }
        }
        "3" {
            $locations = @(
                [PSCustomObject]@{ Index = 1; Path = "$env:USERPROFILE\source\repos"; Name = "Visual Studio Projects" }
                [PSCustomObject]@{ Index = 2; Path = "$env:USERPROFILE\Projects"; Name = "Projects Folder" }
                [PSCustomObject]@{ Index = 3; Path = "C:\projekty"; Name = "C:\projekty" }
                [PSCustomObject]@{ Index = 4; Path = "$env:USERPROFILE\Documents"; Name = "Documents" }
                [PSCustomObject]@{ Index = 5; Path = "$env:USERPROFILE\Desktop"; Name = "Desktop" }
            )

            Write-Host ""
            Write-Host "  Common Locations:" -ForegroundColor Cyan
            foreach ($loc in $locations) {
                $exists = if (Test-Path $loc.Path) { "[✓]" } else { "[✗]" }
                $color = if (Test-Path $loc.Path) { "Green" } else { "DarkGray" }
                Write-Host "    $($loc.Index). " -NoNewline -ForegroundColor White
                Write-Host "$exists " -NoNewline -ForegroundColor $color
                Write-Host "$($loc.Name) " -NoNewline -ForegroundColor White
                Write-Host "($($loc.Path))" -ForegroundColor Gray
            }

            $locChoice = Get-UserChoice -Prompt "Select location" -ValidChoices @("1", "2", "3", "4", "5")
            $selected = $locations | Where-Object { $_.Index -eq [int]$locChoice }

            if ($selected -and (Test-Path $selected.Path)) {
                return $selected.Path
            } else {
                Write-Host "  Invalid or non-existent path, using default" -ForegroundColor Red
                Start-Sleep -Seconds 1
                return $InitialDirectory
            }
        }
        default {
            return $InitialDirectory
        }
    }
}

function Add-Directory {
    param([System.Collections.ArrayList]$Directories)

    Write-Host ""
    Write-Host "  Add Directory" -ForegroundColor Cyan
    Write-Host "  Enter the full path of the directory to add:" -ForegroundColor Gray
    $newDir = Get-UserChoice -Prompt "Path (or press Enter to cancel)"

    if ([string]::IsNullOrWhiteSpace($newDir)) {
        return
    }

    if (-not (Test-Path $newDir)) {
        Write-Host "  Warning: Directory does not exist!" -ForegroundColor Yellow
        $create = Get-UserChoice -Prompt "Add anyway? (y/N)" -ValidChoices @("y", "n", "")
        if ($create -ne "y") {
            return
        }
    }

    if ($Directories -notcontains $newDir) {
        [void]$Directories.Add($newDir)
        Write-Host "  ✓ Directory added" -ForegroundColor Green
    } else {
        Write-Host "  Directory already in list" -ForegroundColor Yellow
    }

    Start-Sleep -Seconds 1
}

function Remove-DirectoryFromList {
    param([System.Collections.ArrayList]$Directories)

    if ($Directories.Count -eq 0) {
        Write-Host "  No directories to remove" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Write-Host ""
    Write-Host "  Remove Directory" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Directories.Count; $i++) {
        Write-Host "    $($i + 1). $($Directories[$i])" -ForegroundColor White
    }

    $choice = Get-UserChoice -Prompt "Select directory to remove (or press Enter to cancel)"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return
    }

    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $Directories.Count) {
        $removed = $Directories[$index]
        $Directories.RemoveAt($index)
        Write-Host "  ✓ Removed: $removed" -ForegroundColor Green
    } else {
        Write-Host "  Invalid selection" -ForegroundColor Red
    }

    Start-Sleep -Seconds 1
}

# ========================= CONFIGURATION =========================

# Script configuration
$scripts = @{
    DevCaches = @{
        Name = "Development Caches Cleanup"
        Description = "Remove NuGet packages, build artifacts, IDE caches"
        File = "scripts/powershell/maintenance/cleanup-dev-caches.ps1"
        Enabled = $true
        Steps = @{
            NuGet = @{ Name = "NuGet Caches (global packages, HTTP cache)"; Enabled = $true }
            BuildArtifacts = @{ Name = "Build Artifacts (obj/bin folders)"; Enabled = $true }
            IDECaches = @{ Name = "IDE Caches (Visual Studio, Rider)"; Enabled = $true }
            VSCode = @{ Name = "VSCode Caches"; Enabled = $true }
            NodeJS = @{ Name = "Node.js/npm Caches"; Enabled = $true }
            Temp = @{ Name = "Temporary Files"; Enabled = $true }
        }
        ProjectDirs = [System.Collections.ArrayList]@("C:\projekty", "$env:USERPROFILE\source\repos", "$env:USERPROFILE\Projects")
    }
    Docker = @{
        Name = "Docker Cleanup"
        Description = "Clean Docker resources and shrink VHDX"
        File = "scripts/powershell/maintenance/cleanup-docker.ps1"
        Enabled = $true
        Steps = @{
            DockerPrune = @{ Name = "Docker System Prune (containers, images, volumes)"; Enabled = $true }
            VHDXShrink = @{ Name = "Shrink Rancher Desktop VHDX"; Enabled = $true }
        }
    }
    DotNetSDK = @{
        Name = ".NET SDK Manager"
        Description = "Manage and remove old .NET SDKs"
        File = "scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1"
        Enabled = $true
        Steps = @{
            ListSDKs = @{ Name = "List installed SDKs"; Enabled = $true }
            RemoveEOL = @{ Name = "Remove EOL versions (.NET 6, 7)"; Enabled = $true }
            RemoveOlder = @{ Name = "Remove older patch versions"; Enabled = $true }
        }
    }
    SQLServer = @{
        Name = "SQL Server Cleanup"
        Description = "Clean backups, logs, and shrink transaction logs"
        File = "scripts/powershell/maintenance/cleanup-sql-server.ps1"
        Enabled = $true
        Steps = @{
            Backups = @{ Name = "Old Backup Files (>30 days)"; Enabled = $true }
            Logs = @{ Name = "Old Error Logs and Traces (>30 days)"; Enabled = $true }
            TransactionLogs = @{ Name = "Shrink Transaction Logs"; Enabled = $true }
        }
    }
}

# ========================= MENU FUNCTIONS =========================

function Show-MainMenu {
    param($Config)

    Show-Header
    Write-Host "  Select Scripts to Run:" -ForegroundColor Yellow
    Write-Host ""

    $index = 1
    foreach ($key in $Config.Keys | Sort-Object) {
        $script = $Config[$key]
        Show-MenuItem -Index $index -Text "$($script.Name) - $($script.Description)" -Enabled $script.Enabled
        $index++
    }

    Write-Host ""
    Write-Host "  Actions:" -ForegroundColor Yellow
    Write-Host "    T. Toggle script enable/disable" -ForegroundColor White
    Write-Host "    C. Configure script steps" -ForegroundColor White
    Write-Host "    R. Run selected scripts" -ForegroundColor White
    Write-Host "    Q. Quit" -ForegroundColor White

    $choice = Get-UserChoice -Prompt "Select action" -ValidChoices @("T", "t", "C", "c", "R", "r", "Q", "q", "1", "2", "3", "4")
    return $choice.ToUpper()
}

function Show-ScriptConfigMenu {
    param($ScriptKey, $Script)

    while ($true) {
        Show-Header
        Write-Host "  Configure: " -NoNewline -ForegroundColor Yellow
        Write-Host $Script.Name -ForegroundColor Cyan
        Write-Host "  " -NoNewline
        Write-Host $Script.Description -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Steps:" -ForegroundColor Yellow
        Write-Host ""

        $index = 1
        $stepKeys = @($Script.Steps.Keys)
        foreach ($stepKey in $stepKeys) {
            $step = $Script.Steps[$stepKey]
            Show-MenuItem -Index $index -Text $step.Name -Enabled $step.Enabled -Indent 4
            $index++
        }

        # Special options for DevCaches
        if ($ScriptKey -eq "DevCaches") {
            Write-Host ""
            Write-Host "  Project Directories for Build Artifacts:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $Script.ProjectDirs.Count; $i++) {
                $exists = Test-Path $Script.ProjectDirs[$i]
                $existsSymbol = if ($exists) { "[✓]" } else { "[✗]" }
                $color = if ($exists) { "Green" } else { "DarkGray" }
                Write-Host "      " -NoNewline
                Write-Host "$existsSymbol " -NoNewline -ForegroundColor $color
                Write-Host $Script.ProjectDirs[$i] -ForegroundColor White
            }

            Write-Host ""
            Write-Host "  Directory Actions:" -ForegroundColor Yellow
            Write-Host "    A. Add directory" -ForegroundColor White
            Write-Host "    D. Remove directory" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "  Actions:" -ForegroundColor Yellow
        Write-Host "    1-$($stepKeys.Count). Toggle step" -ForegroundColor White
        Write-Host "    E. Enable all steps" -ForegroundColor White
        Write-Host "    N. Disable all steps" -ForegroundColor White
        Write-Host "    B. Back to main menu" -ForegroundColor White

        $validChoices = @("E", "e", "N", "n", "B", "b")
        if ($ScriptKey -eq "DevCaches") {
            $validChoices += @("A", "a", "D", "d")
        }
        $validChoices += 1..$stepKeys.Count | ForEach-Object { $_.ToString() }

        $choice = Get-UserChoice -Prompt "Select action" -ValidChoices $validChoices
        $choiceUpper = $choice.ToUpper()

        if ($choiceUpper -eq "B") {
            return
        }
        elseif ($choiceUpper -eq "E") {
            foreach ($stepKey in $stepKeys) {
                $Script.Steps[$stepKey].Enabled = $true
            }
        }
        elseif ($choiceUpper -eq "N") {
            foreach ($stepKey in $stepKeys) {
                $Script.Steps[$stepKey].Enabled = $false
            }
        }
        elseif ($choiceUpper -eq "A" -and $ScriptKey -eq "DevCaches") {
            Add-Directory -Directories $Script.ProjectDirs
        }
        elseif ($choiceUpper -eq "D" -and $ScriptKey -eq "DevCaches") {
            Remove-DirectoryFromList -Directories $Script.ProjectDirs
        }
        elseif ($choice -match '^\d+$') {
            $stepIndex = [int]$choice - 1
            if ($stepIndex -ge 0 -and $stepIndex -lt $stepKeys.Count) {
                $stepKey = $stepKeys[$stepIndex]
                $Script.Steps[$stepKey].Enabled = -not $Script.Steps[$stepKey].Enabled
            }
        }
    }
}

function Toggle-Script {
    param($Config)

    Show-Header
    Write-Host "  Toggle Script Enable/Disable" -ForegroundColor Yellow
    Write-Host ""

    $index = 1
    $scriptKeys = @($Config.Keys | Sort-Object)
    foreach ($key in $scriptKeys) {
        $script = $Config[$key]
        Show-MenuItem -Index $index -Text $script.Name -Enabled $script.Enabled
        $index++
    }

    Write-Host ""
    $choice = Get-UserChoice -Prompt "Select script to toggle (or B to go back)" -ValidChoices (@("B", "b") + (1..$scriptKeys.Count | ForEach-Object { $_.ToString() }))

    if ($choice.ToUpper() -eq "B") {
        return
    }

    $scriptIndex = [int]$choice - 1
    if ($scriptIndex -ge 0 -and $scriptIndex -lt $scriptKeys.Count) {
        $key = $scriptKeys[$scriptIndex]
        $Config[$key].Enabled = -not $Config[$key].Enabled
    }
}

function Select-ScriptToConfigure {
    param($Config)

    Show-Header
    Write-Host "  Configure Script Steps" -ForegroundColor Yellow
    Write-Host ""

    $index = 1
    $scriptKeys = @($Config.Keys | Sort-Object)
    foreach ($key in $scriptKeys) {
        $script = $Config[$key]
        Write-Host "    $index. " -NoNewline -ForegroundColor White
        Write-Host $script.Name -ForegroundColor Cyan
        $index++
    }

    Write-Host ""
    $choice = Get-UserChoice -Prompt "Select script to configure (or B to go back)" -ValidChoices (@("B", "b") + (1..$scriptKeys.Count | ForEach-Object { $_.ToString() }))

    if ($choice.ToUpper() -eq "B") {
        return
    }

    $scriptIndex = [int]$choice - 1
    if ($scriptIndex -ge 0 -and $scriptIndex -lt $scriptKeys.Count) {
        $key = $scriptKeys[$scriptIndex]
        Show-ScriptConfigMenu -ScriptKey $key -Script $Config[$key]
    }
}

# ========================= EXECUTION ENGINE =========================

function Invoke-DevCachesCleanup {
    param($Config)

    $script = $Config.DevCaches
    $totalFreed = 0

    Write-Host "`n=== Development Caches Cleanup ===" -ForegroundColor Yellow
    Write-Host "Running selected steps...`n" -ForegroundColor Gray

    # Helper functions from original script
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
        param([string]$Path, [string]$Description)
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

    # 1. NuGet
    if ($script.Steps.NuGet.Enabled) {
        Write-Host "[1] NuGet Caches" -ForegroundColor Cyan
        $totalFreed += Remove-WithConfirm -Path "$env:USERPROFILE\.nuget\packages" -Description "Global packages"
        $totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\NuGet\Cache" -Description "HTTP cache"
    }

    # 2. Build artifacts
    if ($script.Steps.BuildArtifacts.Enabled) {
        Write-Host "`n[2] Build Artifacts (obj/bin folders)" -ForegroundColor Cyan
        $projectDirs = $script.ProjectDirs

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
            Write-Host "  Calculating total size..." -ForegroundColor Gray
            $totalObjBinSize = 0

            for ($i = 0; $i -lt $allObjBinFolders.Count; $i++) {
                $totalObjBinSize += Get-FolderSize -Path $allObjBinFolders[$i].FullName

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
        }
    }

    # 3. IDE Caches
    if ($script.Steps.IDECaches.Enabled) {
        Write-Host "`n[3] IDE Caches" -ForegroundColor Cyan
        $totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Description "VS ComponentModelCache"
        $totalFreed += Remove-WithConfirm -Path "$env:LOCALAPPDATA\JetBrains\Transient" -Description "Rider transient"
    }

    # 4. VSCode
    if ($script.Steps.VSCode.Enabled) {
        Write-Host "`n[4] VSCode Caches" -ForegroundColor Cyan
        $totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\Cache" -Description "VSCode cache"
        $totalFreed += Remove-WithConfirm -Path "$env:APPDATA\Code\CachedData" -Description "VSCode cached data"
    }

    # 5. Node
    if ($script.Steps.NodeJS.Enabled) {
        Write-Host "`n[5] Node.js Caches" -ForegroundColor Cyan
        $totalFreed += Remove-WithConfirm -Path "$env:APPDATA\npm-cache" -Description "npm cache"
    }

    # 6. Temp
    if ($script.Steps.Temp.Enabled) {
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
    }

    Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green
}

function Invoke-DockerCleanup {
    param($Config)

    $script = $Config.Docker

    Write-Host "`n=== Docker Cleanup ===" -ForegroundColor Yellow
    Write-Host "Running selected steps...`n" -ForegroundColor Gray

    # Helper functions
    function Test-DockerRunning {
        try {
            docker info 2>$null | Out-Null
            return $?
        } catch {
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

    # Docker prune
    if ($script.Steps.DockerPrune.Enabled) {
        if (Test-DockerRunning) {
            Write-Host "[1] Docker System Prune" -ForegroundColor Cyan
            $confirm = Read-Host "  Remove ALL unused containers, images, volumes? (y/N)"

            if ($confirm -eq 'y') {
                try {
                    docker system prune -a -f --volumes
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ Docker cleaned" -ForegroundColor Green
                    } else {
                        Write-Host "  ✗ Docker cleanup failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  ✗ Docker cleanup error: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "[1] Docker not running - skipping prune" -ForegroundColor Yellow
        }
    }

    # VHDX shrink
    if ($script.Steps.VHDXShrink.Enabled) {
        Write-Host "`n[2] Rancher Desktop VHDX Shrink" -ForegroundColor Cyan

        $rancherVhdx = Join-Path $env:LOCALAPPDATA 'rancher-desktop\distro-data\ext4.vhdx'

        if (-not (Test-Path $rancherVhdx)) {
            Write-Host "  ✗ Rancher Desktop VHDX not found at: $rancherVhdx" -ForegroundColor Red
        } else {
            $sizeBefore = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
            Write-Host "  VHDX size: $sizeBefore GB" -ForegroundColor Cyan

            $shrink = Read-Host '  Shrink VHDX? (will stop Rancher & WSL) (y/N)'
            if ($shrink -eq 'y') {
                # Stop everything
                Write-Host "  Stopping Rancher Desktop..." -ForegroundColor Yellow
                $rancherProcess = Get-Process rancher-desktop -ErrorAction SilentlyContinue
                if ($rancherProcess) {
                    Stop-Process -Name rancher-desktop -Force
                    if (-not (Wait-ProcessStop -ProcessName "rancher-desktop" -TimeoutSeconds 15)) {
                        Write-Host "  ✗ Failed to stop Rancher Desktop" -ForegroundColor Red
                        return
                    }
                    Write-Host "  ✓ Rancher Desktop stopped" -ForegroundColor Green
                }

                Write-Host "  Shutting down WSL..." -ForegroundColor Yellow
                wsl --shutdown

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  ✗ WSL shutdown failed" -ForegroundColor Red
                    return
                }

                Start-Sleep -Seconds 3
                $wslState = wsl --list --running 2>$null
                if ($wslState -match "rancher-desktop") {
                    Write-Host "  ✗ WSL still running, cannot proceed" -ForegroundColor Red
                    return
                }
                Write-Host "  ✓ WSL shutdown complete" -ForegroundColor Green

                # Shrink using diskpart
                Write-Host "  Shrinking VHDX (may take several minutes)..." -ForegroundColor Yellow

                $diskpartScript = @"
select vdisk file="$rancherVhdx"
attach vdisk readonly
compact vdisk
detach vdisk
"@

                try {
                    $diskpartOutput = $diskpartScript | diskpart 2>&1

                    if ($diskpartOutput -match "DiskPart successfully") {
                        Write-Host "  ✓ VHDX compacted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  ⚠ Diskpart output:" -ForegroundColor Yellow
                        $diskpartOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                    }
                } catch {
                    Write-Host "  ✗ Diskpart error: $_" -ForegroundColor Red
                    return
                }

                # Verify size reduction
                Start-Sleep -Seconds 2
                $sizeAfter = [math]::Round((Get-Item $rancherVhdx).Length / 1GB, 2)
                $saved = [math]::Round($sizeBefore - $sizeAfter, 2)

                Write-Host ""
                Write-Host "  Before: $($sizeBefore) GB" -ForegroundColor Gray
                Write-Host "  After:  $($sizeAfter) GB" -ForegroundColor Green

                if ($saved -gt 0) {
                    Write-Host "  Saved:  $($saved) GB" -ForegroundColor Green
                } elseif ($saved -eq 0) {
                    Write-Host "  No space saved (VHDX already compact)" -ForegroundColor Yellow
                } else {
                    Write-Host "  ⚠ VHDX size increased (unexpected)" -ForegroundColor Red
                }

                Write-Host ""
                Write-Host "  Done. You can now start Rancher Desktop." -ForegroundColor Cyan
            }
        }
    }
}

function Invoke-DotNetSDKCleanup {
    param($Config)

    $script = $Config.DotNetSDK

    Write-Host "`n=== .NET SDK Manager ===" -ForegroundColor Yellow
    Write-Host "Running selected steps...`n" -ForegroundColor Gray

    # Get installed SDKs
    if ($script.Steps.ListSDKs.Enabled) {
        Write-Host "[1] Listing installed SDKs" -ForegroundColor Cyan

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

        # Group by major version
        $grouped = $installedSdks | Group-Object -Property Major | Sort-Object Name

        Write-Host "`n  Installed SDKs by version:" -ForegroundColor Yellow
        foreach ($group in $grouped) {
            $majorVersion = $group.Name
            $versions = $group.Group | Sort-Object Version -Descending
            $latest = $versions[0]
            $older = $versions | Select-Object -Skip 1

            $ltsTag = if ($latest.IsLTS) { " [LTS]" } else { "" }
            $eolTag = if ($majorVersion -in @(6,7)) { " [EOL]" } else { "" }

            Write-Host "`n  .NET $majorVersion$ltsTag$eolTag" -ForegroundColor Cyan
            Write-Host "    Latest: $($latest.Version)" -ForegroundColor Green

            if ($older.Count -gt 0) {
                Write-Host "    Older versions:" -ForegroundColor Yellow
                foreach ($old in $older) {
                    Write-Host "      - $($old.Version)" -ForegroundColor Gray
                }
            }
        }
    } else {
        # Still need to get the list for other steps
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

        $installedSdks | Where-Object { $_.Major -in @(6,8) } | ForEach-Object { $_.IsLTS = $true }
        $grouped = $installedSdks | Group-Object -Property Major | Sort-Object Name
    }

    # Remove EOL versions
    if ($script.Steps.RemoveEOL.Enabled) {
        Write-Host "`n[2] Remove EOL Versions" -ForegroundColor Cyan
        $eolVersions = $installedSdks | Where-Object { $_.Major -in @(6,7) }
        if ($eolVersions) {
            Write-Host "  Found EOL versions:" -ForegroundColor Yellow
            foreach ($sdk in $eolVersions) {
                Write-Host "    - .NET $($sdk.Version)" -ForegroundColor Gray
            }

            $remove6and7 = Read-Host "  Remove all .NET 6 and 7 SDKs? (y/N)"
            if ($remove6and7 -eq 'y') {
                foreach ($sdk in $eolVersions) {
                    Write-Host "  Removing .NET $($sdk.Version)..." -ForegroundColor Yellow
                    winget uninstall --id "Microsoft.DotNet.SDK.$($sdk.Major)" --version $sdk.Version --silent
                }
                Write-Host "  ✓ EOL versions removed" -ForegroundColor Green
            }
        } else {
            Write-Host "  No EOL versions found" -ForegroundColor Green
        }
    }

    # Remove older patches
    if ($script.Steps.RemoveOlder.Enabled) {
        Write-Host "`n[3] Remove Older Patch Versions" -ForegroundColor Cyan
        $removeOlder = Read-Host "  Remove older patch versions (keep only latest per major)? (y/N)"
        if ($removeOlder -eq 'y') {
            foreach ($group in $grouped | Where-Object { $_.Group.Count -gt 1 -and $_.Name -notin @(6,7) }) {
                $versions = $group.Group | Sort-Object Version -Descending
                $toRemove = $versions | Select-Object -Skip 1

                foreach ($sdk in $toRemove) {
                    Write-Host "  Removing .NET $($sdk.Version)..." -ForegroundColor Yellow
                    winget uninstall --id "Microsoft.DotNet.SDK.$($sdk.Major)" --version $sdk.Version --silent
                }
            }
            Write-Host "  ✓ Older patches removed" -ForegroundColor Green
        }
    }

    Write-Host "`nDone! Run 'dotnet --list-sdks' to verify." -ForegroundColor Cyan
}

function Invoke-SQLServerCleanup {
    param($Config)

    Write-Host "`n=== SQL Server Cleanup ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Note: This is a complex script. Running the full script..." -ForegroundColor Gray
    Write-Host "  For step-by-step control, please run the script directly:" -ForegroundColor Gray
    Write-Host "  pwsh scripts/powershell/maintenance/cleanup-sql-server.ps1" -ForegroundColor Cyan
    Write-Host ""

    $confirm = Read-Host "  Continue with full SQL Server cleanup? (y/N)"
    if ($confirm -eq 'y') {
        & "$PSScriptRoot\scripts\powershell\maintenance\cleanup-sql-server.ps1"
    } else {
        Write-Host "  Skipped" -ForegroundColor Yellow
    }
}

function Start-SelectedScripts {
    param($Config)

    $enabledScripts = @()
    foreach ($key in $Config.Keys) {
        if ($Config[$key].Enabled) {
            $enabledScripts += $key
        }
    }

    if ($enabledScripts.Count -eq 0) {
        Write-Host ""
        Write-Host "  No scripts enabled! Please enable at least one script." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Show-Header
    Write-Host "  Ready to Run:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($key in $enabledScripts) {
        $script = $Config[$key]
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host $script.Name -ForegroundColor White

        $enabledSteps = @($script.Steps.Keys | Where-Object { $script.Steps[$_].Enabled })
        if ($enabledSteps.Count -gt 0) {
            Write-Host "    Steps: " -NoNewline -ForegroundColor Gray
            Write-Host "$($enabledSteps.Count)/$($script.Steps.Count) enabled" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    $confirm = Get-UserChoice -Prompt "Start execution? (y/N)" -ValidChoices @("y", "Y", "n", "N", "")

    if ($confirm.ToLower() -ne 'y') {
        Write-Host "  Cancelled" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Starting Maintenance Scripts..." -ForegroundColor Yellow
    Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Run each enabled script
    foreach ($key in $enabledScripts) {
        switch ($key) {
            "DevCaches" { Invoke-DevCachesCleanup -Config $Config }
            "Docker" { Invoke-DockerCleanup -Config $Config }
            "DotNetSDK" { Invoke-DotNetSDKCleanup -Config $Config }
            "SQLServer" { Invoke-SQLServerCleanup -Config $Config }
        }
    }

    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  All selected scripts completed!" -ForegroundColor Green
    Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    Read-Host "  Press Enter to continue"
}

# ========================= MAIN LOOP =========================

while ($true) {
    $choice = Show-MainMenu -Config $scripts

    switch ($choice) {
        "T" {
            Toggle-Script -Config $scripts
        }
        "C" {
            Select-ScriptToConfigure -Config $scripts
        }
        "R" {
            Start-SelectedScripts -Config $scripts
        }
        "Q" {
            Write-Host ""
            Write-Host "  Goodbye!" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        { $_ -in @("1", "2", "3", "4") } {
            $scriptIndex = [int]$choice - 1
            $scriptKeys = @($scripts.Keys | Sort-Object)
            if ($scriptIndex -ge 0 -and $scriptIndex -lt $scriptKeys.Count) {
                $key = $scriptKeys[$scriptIndex]
                $scripts[$key].Enabled = -not $scripts[$key].Enabled
            }
        }
    }
}
