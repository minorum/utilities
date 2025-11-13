# SQL Server Cleanup Script
# Removes old backups, logs, traces, and shrinks transaction logs

#Requires -RunAsAdministrator

Write-Host "=== SQL Server Cleanup ===" -ForegroundColor Yellow
Write-Host ""

$totalFreed = 0
$daysOld = 30

# Find SQL Server instance
function Get-SqlServerInstance {
    $services = Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Status -eq 'Running' -and $_.Name -like "MSSQL$*" }
    
    if ($services.Count -eq 0) {
        # Check for default instance
        $defaultService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
        if ($defaultService -and $defaultService.Status -eq 'Running') {
            return "localhost"
        }
        return $null
    }
    
    # Get instance name from service
    $firstService = $services[0]
    if ($firstService.Name -eq "MSSQLSERVER") {
        return "localhost"
    } else {
        $instanceName = $firstService.Name -replace "MSSQL\$", ""
        return "localhost\$instanceName"
    }
}

# Check if sqlcmd is available
function Test-SqlCmd {
    $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if (-not $sqlcmd) {
        Write-Host "sqlcmd not found in PATH. Trying common locations..." -ForegroundColor Yellow
        
        $commonPaths = @(
            "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
            "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe",
            "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe",
            "C:\Program Files\Microsoft SQL Server\130\Tools\Binn\sqlcmd.exe",
            "C:\Program Files\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe",
            "C:\Program Files\Microsoft SQL Server\160\Tools\Binn\sqlcmd.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                return $path
            }
        }
        
        return $null
    }
    return "sqlcmd"
}

# Get database log files with sizes
function Get-DatabaseLogInfo {
    param([string]$SqlCmd, [string]$Instance)
    
    $query = @"
SET NOCOUNT ON;
SELECT 
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.name AS LogFileName,
    mf.physical_name AS PhysicalPath,
    CAST(mf.size/128.0 AS DECIMAL(18,2)) AS CurrentSizeMB,
    CAST(CASE 
        WHEN DATABASEPROPERTYEX(DB_NAME(mf.database_id), 'Status') = 'ONLINE'
        THEN mf.size/128.0 - CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS INT)/128.0
        ELSE 0
    END AS DECIMAL(18,2)) AS FreeSpaceMB,
    CAST(CASE 
        WHEN DATABASEPROPERTYEX(DB_NAME(mf.database_id), 'Status') = 'ONLINE'
        THEN CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS INT)/128.0
        ELSE mf.size/128.0
    END AS DECIMAL(18,2)) AS UsedSpaceMB,
    DATABASEPROPERTYEX(DB_NAME(mf.database_id), 'Status') AS DbStatus
FROM sys.master_files mf
WHERE mf.type_desc = 'LOG' 
    AND mf.database_id > 4
    AND DB_NAME(mf.database_id) NOT IN ('master', 'model', 'msdb', 'tempdb')
    AND DATABASEPROPERTYEX(DB_NAME(mf.database_id), 'Status') IS NOT NULL
ORDER BY CurrentSizeMB DESC;
"@
    
    try {
        # Execute query and capture output
        $output = & $SqlCmd -S $Instance -E -Q $query -h -1 -W -s "," 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  sqlcmd returned error code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "  Output: $output" -ForegroundColor Red
            return @()
        }
        
        $logs = @()
        foreach ($line in $output) {
            # Skip empty lines and trim whitespace
            $line = $line.ToString().Trim()
            if (-not $line -or $line.Length -eq 0) { continue }
            
            # Skip error messages
            if ($line -match "^(Msg |Error |Warning )") { continue }
            
            # Parse CSV line
            $parts = $line -split ',' | ForEach-Object { $_.Trim() }
            
            if ($parts.Count -ge 7) {
                # Try to parse numeric values
                $currentSize = 0.0
                $freeSpace = 0.0
                $usedSpace = 0.0
                
                $parseSuccess = [double]::TryParse($parts[3], [ref]$currentSize) -and
                               [double]::TryParse($parts[4], [ref]$freeSpace) -and
                               [double]::TryParse($parts[5], [ref]$usedSpace)
                
                if ($parseSuccess -and $currentSize -gt 0) {
                    $logs += [PSCustomObject]@{
                        Database = $parts[0]
                        LogFileName = $parts[1]
                        PhysicalPath = $parts[2]
                        CurrentSizeMB = [math]::Round($currentSize, 2)
                        FreeSpaceMB = [math]::Round($freeSpace, 2)
                        UsedSpaceMB = [math]::Round($usedSpace, 2)
                        Status = $parts[6]
                    }
                }
            }
        }
        
        return $logs
    } catch {
        Write-Host "  Error querying database logs: $_" -ForegroundColor Red
        return @()
    }
}

# Shrink log file
function Shrink-LogFile {
    param(
        [string]$SqlCmd,
        [string]$Instance,
        [string]$Database,
        [string]$LogFileName,
        [int]$TargetSizeMB = 100
    )
    
    $query = @"
USE [$Database];
CHECKPOINT;
DBCC SHRINKFILE (N'$LogFileName', $TargetSizeMB);
"@
    
    try {
        Write-Host "  Shrinking $Database log to ${TargetSizeMB}MB..." -ForegroundColor Yellow
        $output = & $SqlCmd -S $Instance -E -Q $query -b 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Shrunk successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Failed to shrink (exit code: $LASTEXITCODE)" -ForegroundColor Red
            if ($output) {
                Write-Host "  Output: $output" -ForegroundColor DarkGray
            }
            return $false
        }
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

# === MAIN SCRIPT ===

# 1. Backups
Write-Host "[1] SQL Server Backups (older than $daysOld days)" -ForegroundColor Cyan
$backupDirs = Get-ChildItem "C:\Program Files\Microsoft SQL Server\MSSQL*\MSSQL\Backup\" -ErrorAction SilentlyContinue

$foundBackups = $false
foreach ($dir in $backupDirs) {
    $oldBackups = Get-ChildItem $dir.FullName -Filter *.bak -ErrorAction SilentlyContinue | 
                  Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysOld)}
    
    if ($oldBackups) {
        $foundBackups = $true
        $totalSize = ($oldBackups | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Host "  $($dir.Name): $($oldBackups.Count) files, $([math]::Round($totalSize, 2)) GB" -ForegroundColor Yellow
        $confirm = Read-Host "  Remove? (y/N)"
        if ($confirm -eq 'y') {
            $oldBackups | Remove-Item -Force
            $totalFreed += $totalSize
            Write-Host "  ✓ Removed" -ForegroundColor Green
        }
    }
}

if (-not $foundBackups) {
    Write-Host "  No old backups found" -ForegroundColor Green
}

# 2. Error logs and traces
Write-Host "`n[2] SQL Server Logs (older than $daysOld days)" -ForegroundColor Cyan
$logDirs = Get-ChildItem "C:\Program Files\Microsoft SQL Server\MSSQL*\MSSQL\LOG\" -ErrorAction SilentlyContinue

$foundLogs = $false
foreach ($dir in $logDirs) {
    $oldLogs = Get-ChildItem $dir.FullName -Include *.trc, *.mdmp, *.txt -Recurse -ErrorAction SilentlyContinue | 
               Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysOld)}
    
    if ($oldLogs) {
        $foundLogs = $true
        $totalSize = ($oldLogs | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Host "  $($dir.Name): $($oldLogs.Count) files, $([math]::Round($totalSize, 2)) GB" -ForegroundColor Yellow
        $confirm = Read-Host "  Remove? (y/N)"
        if ($confirm -eq 'y') {
            $oldLogs | Remove-Item -Force
            $totalFreed += $totalSize
            Write-Host "  ✓ Removed" -ForegroundColor Green
        }
    }
}

if (-not $foundLogs) {
    Write-Host "  No old logs found" -ForegroundColor Green
}

# 3. Transaction Logs
Write-Host "`n[3] Database Transaction Logs" -ForegroundColor Cyan

# Find sqlcmd
$sqlcmdPath = Test-SqlCmd
if (-not $sqlcmdPath) {
    Write-Host "  sqlcmd not found. Cannot shrink logs automatically." -ForegroundColor Red
    Write-Host "  Install SQL Server Command Line Utilities or run manually in SSMS." -ForegroundColor Yellow
} else {
    # Find SQL Server instance
    $instance = Get-SqlServerInstance
    if (-not $instance) {
        Write-Host "  No running SQL Server instance found." -ForegroundColor Red
    } else {
        Write-Host "  Connected to: $instance" -ForegroundColor Gray
        
        # Get log file information
        Write-Host "  Querying database log files..." -ForegroundColor Gray
        $logFiles = Get-DatabaseLogInfo -SqlCmd $sqlcmdPath -Instance $instance
        
        if ($logFiles.Count -eq 0) {
            Write-Host "  No user databases with transaction logs found." -ForegroundColor Yellow
            Write-Host "  This might mean:" -ForegroundColor Gray
            Write-Host "    - No user databases exist" -ForegroundColor Gray
            Write-Host "    - All databases are offline" -ForegroundColor Gray
            Write-Host "    - Insufficient permissions" -ForegroundColor Gray
        } else {
            Write-Host "`n  Database Transaction Logs:" -ForegroundColor Yellow
            Write-Host "  " ("-" * 95) -ForegroundColor Gray
            Write-Host ("  {0,-25} {1,-10} {2,12} {3,12} {4,12}" -f "Database", "Status", "Total (MB)", "Used (MB)", "Free (MB)") -ForegroundColor Gray
            Write-Host "  " ("-" * 95) -ForegroundColor Gray
            
            $logsToShrink = @()
            foreach ($log in $logFiles) {
                $statusColor = if ($log.Status -eq "ONLINE") { "White" } else { "DarkGray" }
                Write-Host ("  {0,-25} {1,-10} {2,12:N2} {3,12:N2} {4,12:N2}" -f 
                    $log.Database, 
                    $log.Status,
                    $log.CurrentSizeMB, 
                    $log.UsedSpaceMB, 
                    $log.FreeSpaceMB) -ForegroundColor $statusColor
                
                # Recommend shrinking if ONLINE, >50% free and >500MB free
                if ($log.Status -eq "ONLINE" -and 
                    $log.FreeSpaceMB -gt 500 -and 
                    $log.CurrentSizeMB -gt 0 -and
                    ($log.FreeSpaceMB / $log.CurrentSizeMB) -gt 0.5) {
                    Write-Host "    → Recommend shrinking (>500MB free space)" -ForegroundColor Yellow
                    $logsToShrink += $log
                }
            }
            
            if ($logsToShrink.Count -gt 0) {
                Write-Host "`n  Potential space to recover: $([math]::Round(($logsToShrink | Measure-Object -Property FreeSpaceMB -Sum).Sum / 1024, 2)) GB" -ForegroundColor Yellow
                
                $shrinkAll = Read-Host "`n  Shrink all recommended logs? (y/N)"
                if ($shrinkAll -eq 'y') {
                    $freedFromLogs = 0
                    foreach ($log in $logsToShrink) {
                        $sizeBefore = $log.CurrentSizeMB
                        $targetSize = [math]::Max(100, [math]::Ceiling($log.UsedSpaceMB * 1.2))
                        $success = Shrink-LogFile -SqlCmd $sqlcmdPath -Instance $instance `
                                                  -Database $log.Database -LogFileName $log.LogFileName `
                                                  -TargetSizeMB $targetSize
                        if ($success) {
                            # Estimate freed space (conservative: 80% of free space)
                            $freedFromLogs += ($log.FreeSpaceMB * 0.8) / 1024
                        }
                    }
                    
                    $totalFreed += $freedFromLogs
                    
                    # Show results
                    Write-Host "`n  Refreshing log sizes..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    $newLogFiles = Get-DatabaseLogInfo -SqlCmd $sqlcmdPath -Instance $instance
                    
                    if ($newLogFiles.Count -gt 0) {
                        Write-Host "  " ("-" * 95) -ForegroundColor Gray
                        Write-Host ("  {0,-25} {1,-10} {2,12} {3,12} {4,12}" -f "Database", "Status", "Total (MB)", "Used (MB)", "Free (MB)") -ForegroundColor Gray
                        Write-Host "  " ("-" * 95) -ForegroundColor Gray
                        
                        foreach ($log in $newLogFiles | Where-Object { $_.Database -in $logsToShrink.Database }) {
                            Write-Host ("  {0,-25} {1,-10} {2,12:N2} {3,12:N2} {4,12:N2}" -f 
                                $log.Database, 
                                $log.Status,
                                $log.CurrentSizeMB, 
                                $log.UsedSpaceMB, 
                                $log.FreeSpaceMB) -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Host "`n  Manual shrink commands:" -ForegroundColor Gray
                    foreach ($log in $logsToShrink) {
                        $targetSize = [math]::Max(100, [math]::Ceiling($log.UsedSpaceMB * 1.2))
                        Write-Host "  USE [$($log.Database)]; DBCC SHRINKFILE (N'$($log.LogFileName)', $targetSize);" -ForegroundColor DarkGray
                    }
                }
            } else {
                Write-Host "`n  ✓ All logs are optimally sized" -ForegroundColor Green
            }
        }
    }
}

Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green