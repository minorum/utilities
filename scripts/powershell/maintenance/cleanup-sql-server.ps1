# SQL Server Cleanup Script
# Removes old backups, logs, traces

#Requires -RunAsAdministrator

Write-Host "=== SQL Server Cleanup ===" -ForegroundColor Yellow
Write-Host ""

$totalFreed = 0
$daysOld = 30

# 1. Backups
Write-Host "[1] SQL Server Backups (older than $daysOld days)" -ForegroundColor Cyan
$backupDirs = Get-ChildItem "C:\Program Files\Microsoft SQL Server\MSSQL*\MSSQL\Backup\" -ErrorAction SilentlyContinue

foreach ($dir in $backupDirs) {
    $oldBackups = Get-ChildItem $dir.FullName -Filter *.bak -ErrorAction SilentlyContinue | 
                  Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysOld)}
    
    if ($oldBackups) {
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

# 2. Error logs and traces
Write-Host "`n[2] SQL Server Logs (older than $daysOld days)" -ForegroundColor Cyan
$logDirs = Get-ChildItem "C:\Program Files\Microsoft SQL Server\MSSQL*\MSSQL\LOG\" -ErrorAction SilentlyContinue

foreach ($dir in $logDirs) {
    $oldLogs = Get-ChildItem $dir.FullName -Include *.trc, *.mdmp, *.txt -Recurse -ErrorAction SilentlyContinue | 
               Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysOld)}
    
    if ($oldLogs) {
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

# 3. Suggest log shrinking
Write-Host "`n[3] Database Transaction Logs" -ForegroundColor Cyan
Write-Host "  To shrink logs, run in SSMS:" -ForegroundColor Gray
Write-Host @"
  USE YourDevDatabase;
  DBCC SHRINKFILE (YourLogFileName, 1);
"@ -ForegroundColor DarkGray

Write-Host "`n=== Total freed: $([math]::Round($totalFreed, 2)) GB ===" -ForegroundColor Green