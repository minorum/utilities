#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Interactive TUI menu for Windows maintenance scripts using Spectre.Console
.DESCRIPTION
    Central entrypoint for all maintenance scripts with a modern, interactive interface.
    Allows selecting scripts, configuring steps, and managing directories.
.NOTES
    Requires: PwshSpectreConsole module (will auto-install if missing)
#>

$ErrorActionPreference = 'Stop'

# ========================= MODULE CHECK =========================

function Install-SpectreConsoleIfNeeded {
    if (-not (Get-Module -ListAvailable -Name PwshSpectreConsole)) {
        Write-Host "Installing PwshSpectreConsole module (one-time setup)..." -ForegroundColor Yellow
        try {
            Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force -AllowClobber
            Write-Host "✓ Module installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to install module: $_" -ForegroundColor Red
            Write-Host "`nPlease install manually: Install-Module -Name PwshSpectreConsole" -ForegroundColor Yellow
            exit 1
        }
    }
    Import-Module PwshSpectreConsole -ErrorAction Stop
}

Install-SpectreConsoleIfNeeded

# ========================= CONFIGURATION =========================

$scripts = @{
    DevCaches = @{
        Name = "Development Caches"
        Description = "Remove NuGet, build artifacts, IDE caches"
        File = "scripts/powershell/maintenance/cleanup-dev-caches.ps1"
        Enabled = $true
        Steps = @{
            NuGet = @{ Name = "NuGet Caches"; Enabled = $true }
            BuildArtifacts = @{ Name = "Build Artifacts (obj/bin)"; Enabled = $true }
            IDECaches = @{ Name = "IDE Caches (VS, Rider)"; Enabled = $true }
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
            DockerPrune = @{ Name = "Docker System Prune"; Enabled = $true }
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
        Description = "Clean backups, logs, shrink transaction logs"
        File = "scripts/powershell/maintenance/cleanup-sql-server.ps1"
        Enabled = $true
        Steps = @{
            Backups = @{ Name = "Old Backup Files (>30 days)"; Enabled = $true }
            Logs = @{ Name = "Old Error Logs (>30 days)"; Enabled = $true }
            TransactionLogs = @{ Name = "Shrink Transaction Logs"; Enabled = $true }
        }
    }
}

# ========================= MENU FUNCTIONS =========================

function Show-MainMenu {
    param($Config)

    Clear-Host
    Write-SpectreHost "`n[cyan bold]╔══════════════════════════════════════════════════════╗[/]"
    Write-SpectreHost "[cyan bold]║[/]  [yellow bold]Windows Maintenance Scripts[/]                    [cyan bold]║[/]"
    Write-SpectreHost "[cyan bold]╚══════════════════════════════════════════════════════╝[/]`n"
    Write-SpectreHost "[dim]Select scripts to run and configure options[/]`n"

    $choices = @(
        "Select Scripts to Run"
        "Configure Script Steps"
        "Run Selected Scripts"
        "Exit"
    )

    $selection = Read-SpectreSelection -Message "What would you like to do?" -Choices $choices
    return $selection
}

function Select-Scripts {
    param($Config)

    Write-SpectreHost "`n[cyan bold]Select Scripts to Run[/]`n"

    $scriptList = $Config.Keys | Sort-Object | ForEach-Object {
        $script = $Config[$_]
        $status = if ($script.Enabled) { "[green]✓[/]" } else { "[dim][ ][/]" }
        "$status $($script.Name) - $($script.Description)"
    }

    $selected = Read-SpectreMultiSelection -Title "Use Space to toggle, Enter to confirm" -Choices $scriptList

    # Update enabled status based on selection
    foreach ($key in $Config.Keys) {
        $script = $Config[$key]
        # Check both enabled and disabled versions
        $enabledText = "[green]✓[/] $($script.Name) - $($script.Description)"
        $disabledText = "[dim][ ][/] $($script.Name) - $($script.Description)"

        $Config[$key].Enabled = ($selected -contains $enabledText) -or ($selected -contains $disabledText)
    }
}

function Configure-ScriptSteps {
    param($Config)

    # Let user pick which script to configure
    $scriptChoices = $Config.Keys | Sort-Object | ForEach-Object {
        $Config[$_].Name
    }

    $selectedScript = Read-SpectreSelection -Message "Which script would you like to configure?" `
                                           -Choices ($scriptChoices + @("← Back"))

    if ($selectedScript -eq "← Back") { return }

    # Find the script key
    $scriptKey = $Config.Keys | Where-Object { $Config[$_].Name -eq $selectedScript } | Select-Object -First 1
    $script = $Config[$scriptKey]

    # Configure steps
    while ($true) {
        Clear-Host
        Write-SpectreHost "`n[cyan bold]══ $($script.Name) ══[/]"
        Write-SpectreHost "[dim]$($script.Description)[/]`n"

        $stepChoices = @(
            "Toggle Individual Steps"
            "Enable All Steps"
            "Disable All Steps"
        )

        if ($scriptKey -eq "DevCaches") {
            $stepChoices += @("Manage Project Directories", "← Back")
        } else {
            $stepChoices += "← Back"
        }

        $action = Read-SpectreSelection -Message "Configure $($script.Name)" -Choices $stepChoices

        switch ($action) {
            "Toggle Individual Steps" {
                $stepList = $script.Steps.Keys | ForEach-Object {
                    $step = $script.Steps[$_]
                    $status = if ($step.Enabled) { "[green]✓[/]" } else { "[dim][ ][/]" }
                    "$status $($step.Name)"
                }

                $selected = Read-SpectreMultiSelection -Title "Select steps to enable (Space to toggle)" -Choices $stepList

                # Update step status
                foreach ($stepKey in $script.Steps.Keys) {
                    $step = $script.Steps[$stepKey]
                    $enabledText = "[green]✓[/] $($step.Name)"
                    $disabledText = "[dim][ ][/] $($step.Name)"
                    $script.Steps[$stepKey].Enabled = ($selected -contains $enabledText) -or ($selected -contains $disabledText)
                }
            }
            "Enable All Steps" {
                foreach ($stepKey in $script.Steps.Keys) {
                    $script.Steps[$stepKey].Enabled = $true
                }
                Write-SpectreHost "[green]✓ All steps enabled[/]"
                Start-Sleep -Seconds 1
            }
            "Disable All Steps" {
                foreach ($stepKey in $script.Steps.Keys) {
                    $script.Steps[$stepKey].Enabled = $false
                }
                Write-SpectreHost "[yellow]✓ All steps disabled[/]"
                Start-Sleep -Seconds 1
            }
            "Manage Project Directories" {
                Manage-ProjectDirectories -Script $script
            }
            "← Back" { return }
        }
    }
}

function Manage-ProjectDirectories {
    param($Script)

    while ($true) {
        Clear-Host
        Write-SpectreHost "`n[cyan bold]══ Project Directories ══[/]"
        Write-SpectreHost "[dim]Directories to scan for build artifacts (obj/bin folders)[/]`n"

        # Show current directories
        if ($Script.ProjectDirs.Count -gt 0) {
            $table = @()
            for ($i = 0; $i -lt $Script.ProjectDirs.Count; $i++) {
                $dir = $Script.ProjectDirs[$i]
                $exists = Test-Path $dir
                $status = if ($exists) { "[green]✓ Exists[/]" } else { "[red]✗ Not Found[/]" }
                $table += [PSCustomObject]@{
                    "#" = $i + 1
                    "Status" = $status
                    "Path" = $dir
                }
            }

            $table | Format-SpectreTable
            Write-Host ""
        } else {
            Write-SpectreHost "[yellow]No directories configured[/]`n"
        }

        $choices = @("Add Directory", "Remove Directory", "← Back")
        $action = Read-SpectreSelection -Message "Manage directories" -Choices $choices

        switch ($action) {
            "Add Directory" {
                $newDir = Read-SpectreText -Prompt "Enter directory path"
                if (-not [string]::IsNullOrWhiteSpace($newDir)) {
                    if ($Script.ProjectDirs -notcontains $newDir) {
                        [void]$Script.ProjectDirs.Add($newDir)
                        Write-SpectreHost "[green]✓ Directory added[/]"
                    } else {
                        Write-SpectreHost "[yellow]Directory already in list[/]"
                    }
                    Start-Sleep -Seconds 1
                }
            }
            "Remove Directory" {
                if ($Script.ProjectDirs.Count -gt 0) {
                    $dirChoices = for ($i = 0; $i -lt $Script.ProjectDirs.Count; $i++) {
                        "$($i + 1). $($Script.ProjectDirs[$i])"
                    }
                    $dirChoices += "← Cancel"

                    $selected = Read-SpectreSelection -Message "Select directory to remove" -Choices $dirChoices

                    if ($selected -ne "← Cancel") {
                        $index = [int]($selected -split '\.')[0] - 1
                        $removed = $Script.ProjectDirs[$index]
                        $Script.ProjectDirs.RemoveAt($index)
                        Write-SpectreHost "[green]✓ Removed: $removed[/]"
                        Start-Sleep -Seconds 1
                    }
                } else {
                    Write-SpectreHost "[yellow]No directories to remove[/]"
                    Start-Sleep -Seconds 1
                }
            }
            "← Back" { return }
        }
    }
}

function Start-SelectedScripts {
    param($Config)

    $enabledScripts = $Config.Keys | Where-Object { $Config[$_].Enabled }

    if ($enabledScripts.Count -eq 0) {
        Write-SpectreHost "[red]✗ No scripts enabled! Please enable at least one script.[/]"
        Start-Sleep -Seconds 2
        return
    }

    Clear-Host
    Write-SpectreHost "`n[green bold]══ Ready to Execute ══[/]"
    Write-SpectreHost "[dim]The following scripts will run with your configuration[/]`n"

    # Show what will run
    foreach ($key in $enabledScripts) {
        $script = $Config[$key]
        Write-SpectreHost "[green]✓[/] $($script.Name)"

        $enabledSteps = @($script.Steps.Keys | Where-Object { $script.Steps[$_].Enabled })
        Write-SpectreHost "  [dim]Steps: $($enabledSteps.Count)/$($script.Steps.Count) enabled[/]"
    }

    Write-Host ""
    $confirm = Read-SpectreConfirm -Prompt "Start execution?" -DefaultAnswer $false

    if (-not $confirm) {
        Write-SpectreHost "[yellow]Cancelled[/]"
        Start-Sleep -Seconds 1
        return
    }

    # Run each script
    Clear-Host
    Write-SpectreHost "`n[cyan bold]══ Executing Maintenance Scripts ══[/]`n"

    foreach ($key in $enabledScripts) {
        switch ($key) {
            "DevCaches" { Invoke-DevCachesCleanup -Config $Config }
            "Docker" { Invoke-DockerCleanup -Config $Config }
            "DotNetSDK" { Invoke-DotNetSDKCleanup -Config $Config }
            "SQLServer" { Invoke-SQLServerCleanup -Config $Config }
        }
    }

    Write-Host ""
    Write-SpectreHost "[green bold]══ Completed ══[/]"
    Write-SpectreHost "[dim]All selected scripts have finished executing[/]`n"
    Read-Host "Press Enter to continue"
}

# ========================= EXECUTION FUNCTIONS =========================
# These are simplified versions that call the actual scripts with configuration

function Invoke-DevCachesCleanup {
    param($Config)
    Write-SpectreHost "`n[cyan bold]═══ Development Caches Cleanup ═══[/]`n"

    # For now, run the full script
    # TODO: Could be refactored to pass configuration to the script
    $scriptPath = Join-Path $PSScriptRoot $Config.DevCaches.File
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-SpectreHost "[yellow]⚠ Script not found: $scriptPath[/]"
    }
}

function Invoke-DockerCleanup {
    param($Config)
    Write-SpectreHost "`n[cyan bold]═══ Docker Cleanup ═══[/]`n"

    $scriptPath = Join-Path $PSScriptRoot $Config.Docker.File
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-SpectreHost "[yellow]⚠ Script not found: $scriptPath[/]"
    }
}

function Invoke-DotNetSDKCleanup {
    param($Config)
    Write-SpectreHost "`n[cyan bold]═══ .NET SDK Manager ═══[/]`n"

    $scriptPath = Join-Path $PSScriptRoot $Config.DotNetSDK.File
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-SpectreHost "[yellow]⚠ Script not found: $scriptPath[/]"
    }
}

function Invoke-SQLServerCleanup {
    param($Config)
    Write-SpectreHost "`n[cyan bold]═══ SQL Server Cleanup ═══[/]`n"

    $scriptPath = Join-Path $PSScriptRoot $Config.SQLServer.File
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-SpectreHost "[yellow]⚠ Script not found: $scriptPath[/]"
    }
}

# ========================= MAIN LOOP =========================

Clear-Host
Write-SpectreHost "`n[cyan bold]╔══════════════════════════════════════════════════════╗[/]"
Write-SpectreHost "[cyan bold]║[/]  [yellow bold]Windows Maintenance Scripts[/]                    [cyan bold]║[/]"
Write-SpectreHost "[cyan bold]╚══════════════════════════════════════════════════════╝[/]"
Write-SpectreHost "[dim]Interactive TUI Menu powered by Spectre.Console[/]`n"
Start-Sleep -Seconds 1

while ($true) {
    $choice = Show-MainMenu -Config $scripts

    switch ($choice) {
        "Select Scripts to Run" {
            Select-Scripts -Config $scripts
        }
        "Configure Script Steps" {
            Configure-ScriptSteps -Config $scripts
        }
        "Run Selected Scripts" {
            Start-SelectedScripts -Config $scripts
        }
        "Exit" {
            Clear-Host
            Write-SpectreHost "`n[cyan]Goodbye![/]`n"
            exit 0
        }
    }
}
