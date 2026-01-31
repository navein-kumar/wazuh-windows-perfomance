@echo off
setlocal enabledelayedexpansion

REM Variables
set NSSM_URL=https://github.com/navein-kumar/wazuh-Netstat-Powershell/raw/refs/heads/main/nssm.exe
set INSTALL_DIR=C:\WazuhPerformance
set SERVICE_NAME=WazuhPerformanceMonitor
set LOG_DIR=%INSTALL_DIR%\logs

echo === Wazuh Performance Monitor Installation (v2 - Multi-Drive) ===

REM Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator!
    pause
    exit /b 1
)

REM Cleanup existing
sc stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 /nobreak >nul
sc delete "%SERVICE_NAME%" >nul 2>&1
if exist "%INSTALL_DIR%\nssm.exe" (
    "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm >nul 2>&1
)
taskkill /f /im powershell.exe /fi "WINDOWTITLE eq *service_runner*" >nul 2>&1
timeout /t 3 /nobreak >nul
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" >nul 2>&1

REM Create directories
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%LOG_DIR%" 2>nul

REM Download NSSM
echo Downloading NSSM...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%NSSM_URL%' -OutFile '%INSTALL_DIR%\nssm.exe' -UseBasicParsing"

REM Create complete performance script with all features
echo Creating performance monitor script...
(
echo # Windows Performance Monitor for Wazuh - v2 Multi-Drive Support
echo $logDir = "C:\WazuhPerformance\logs"
echo $today = Get-Date -Format "yyyy-MM-dd"
echo $logFile = "$logDir\performance_$today.json"
echo.
echo try {
echo     # Ensure log directory exists
echo     if ^(-not ^(Test-Path $logDir^)^) {
echo         New-Item -ItemType Directory -Path $logDir -Force ^| Out-Null
echo     }
echo.
echo     # Get CPU utilization
echo     $cpuPercent = 0
echo     $cpuCores = 0
echo     try {
echo         $cpu = Get-WmiObject -Class Win32_Processor ^| Select-Object -First 1
echo         $cpuCores = $cpu.NumberOfLogicalProcessors
echo         if ^($cpu.LoadPercentage^) {
echo             $cpuPercent = $cpu.LoadPercentage
echo         } else {
echo             # Fallback to performance counter
echo             $perfCounter = Get-Counter "\Processor^(_Total^)\%% Processor Time" -SampleInterval 1 -MaxSamples 1
echo             $cpuPercent = [math]::Round^($perfCounter.CounterSamples[0].CookedValue, 0^)
echo         }
echo     } catch {
echo         $cpuPercent = 0
echo     }
echo     $cpuFreePercent = 100 - $cpuPercent
echo     $cpuUsedCore = [math]::Round^(^($cpuPercent / 100^) * $cpuCores, 0^)
echo     $cpuFreeCore = $cpuCores - $cpuUsedCore
echo.
echo     # Get Memory information
echo     $memory = Get-WmiObject -Class Win32_OperatingSystem
echo     $memTotalKB = $memory.TotalVisibleMemorySize
echo     $memFreeKB = $memory.FreePhysicalMemory
echo     $memUsedKB = $memTotalKB - $memFreeKB
echo     $memUsedPercent = [math]::Round^(^($memUsedKB / $memTotalKB^) * 100, 0^)
echo.
echo     # Get ALL Disk information ^(Fixed drives only^)
echo     $allDisks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"
echo     $diskHighest = 0
echo     $diskAlertDrive = ""
echo     $diskDetails = @^(^)
echo.
echo     foreach ^($disk in $allDisks^) {
echo         $driveLetter = $disk.DeviceID -replace ":",""
echo         $diskTotalGB = [math]::Round^($disk.Size / 1GB, 0^)
echo         $diskFreeGB = [math]::Round^($disk.FreeSpace / 1GB, 0^)
echo         $diskUsedGB = $diskTotalGB - $diskFreeGB
echo         $diskUsedPercent = [math]::Round^(^($diskUsedGB / $diskTotalGB^) * 100, 0^)
echo.
echo         # Track highest disk usage for alert
echo         if ^($diskUsedPercent -gt $diskHighest^) {
echo             $diskHighest = $diskUsedPercent
echo             $diskAlertDrive = $driveLetter
echo         }
echo.
echo         $diskDetails += @{
echo             "drive" = $driveLetter
echo             "total_gb" = [string]$diskTotalGB
echo             "used_gb" = [string]$diskUsedGB
echo             "free_gb" = [string]$diskFreeGB
echo             "used_percent" = [string]$diskUsedPercent
echo         }
echo     }
echo.
echo     # Get Network adapters
echo     $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapter -Filter "NetConnectionStatus=2"
echo     $activeNetworkCount = ^($networkAdapters ^| Measure-Object^).Count
echo.
echo     # Get System uptime
echo     $bootTime = ^(Get-WmiObject Win32_OperatingSystem^).LastBootUpTime
echo     $bootTimeFormatted = [Management.ManagementDateTimeConverter]::ToDateTime^($bootTime^)
echo     $uptime = ^(Get-Date^) - $bootTimeFormatted
echo     $uptimeHours = [math]::Round^($uptime.TotalHours, 0^)
echo.
echo     # Create comprehensive performance object with ordered output
echo     $perfData = [ordered]@{
echo         "wazuhlogtype" = "wazuhperformance"
echo         "log_timestamp" = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
echo         "hostname" = $env:COMPUTERNAME
echo         "domain" = $env:USERDOMAIN
echo         "os_version" = $memory.Caption
echo         "cpu_total_core" = [string]$cpuCores
echo         "cpu_used_core" = [string]$cpuUsedCore
echo         "cpu_free_core" = [string]$cpuFreeCore
echo         "cpu_used_percent" = [string]$cpuPercent
echo         "memory_total_gb" = [string][math]::Round^($memTotalKB / 1MB, 0^)
echo         "memory_used_gb" = [string][math]::Round^($memUsedKB / 1MB, 0^)
echo         "memory_free_gb" = [string][math]::Round^($memFreeKB / 1MB, 0^)
echo         "memory_used_percent" = [string]$memUsedPercent
echo         "disk_highest_percent" = [string]$diskHighest
echo         "disk_alert_drive" = $diskAlertDrive
echo         "disk_count" = [string]$diskDetails.Count
echo         "network_adapters_active" = [string]$activeNetworkCount
echo         "uptime_hours" = [string]$uptimeHours
echo     }
echo.
echo     # Add individual disk details
echo     foreach ^($d in $diskDetails^) {
echo         $prefix = "disk_" + $d.drive.ToLower^(^)
echo         $perfData["$prefix`_total_gb"] = $d.total_gb
echo         $perfData["$prefix`_used_gb"] = $d.used_gb
echo         $perfData["$prefix`_free_gb"] = $d.free_gb
echo         $perfData["$prefix`_used_percent"] = $d.used_percent
echo     }
echo.
echo     # Convert to JSON and write to file
echo     $json = $perfData ^| ConvertTo-Json -Compress
echo     $json ^| Out-File -FilePath $logFile -Append -Encoding UTF8
echo.
echo     # Log rotation - Clean old logs ^(older than 7 days^) every hour at minute 0
echo     if ^(^(Get-Date^).Minute -eq 0^) {
echo         try {
echo             $cutoffDate = ^(Get-Date^).AddDays^(-7^)
echo             $oldLogs = Get-ChildItem -Path $logDir -Filter "performance_*.json" ^| Where-Object { $_.LastWriteTime -lt $cutoffDate }
echo             if ^($oldLogs^) {
echo                 $oldLogs ^| Remove-Item -Force
echo                 Write-Host "Cleaned $^($oldLogs.Count^) old log files"
echo             }
echo         } catch {
echo             # Silent cleanup failure
echo         }
echo     }
echo.
echo } catch {
echo     # Error handling - log errors to separate file
echo     try {
echo         $errorData = @{
echo             "log_timestamp" = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
echo             "hostname" = $env:COMPUTERNAME
echo             "error" = $_.Exception.Message
echo             "error_type" = "performance_collection_failed"
echo         }
echo         $errorJson = $errorData ^| ConvertTo-Json -Compress
echo         $errorJson ^| Out-File -FilePath "$logDir\performance_errors_$today.json" -Append -Encoding UTF8
echo     } catch {
echo         # Silent error logging failure
echo     }
echo }
) > "%INSTALL_DIR%\performance_monitor.ps1"

REM Create service runner with error handling
echo Creating service runner script...
(
echo # Service wrapper for Windows Performance Monitor
echo $ErrorActionPreference = "Continue"
echo.
echo while ^($true^) {
echo     try {
echo         ^& "C:\WazuhPerformance\performance_monitor.ps1"
echo     } catch {
echo         # Log service runner errors
echo         $errorMsg = "Service runner error: $^($_.Exception.Message^)"
echo         $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo         "$timestamp`: $errorMsg" ^| Out-File "C:\WazuhPerformance\logs\service_errors.log" -Append
echo     }
echo
echo     # Wait 60 seconds before next collection
echo     Start-Sleep -Seconds 60
echo }
) > "%INSTALL_DIR%\service_runner.ps1"

REM Install and configure service
echo Installing Windows service...
"%INSTALL_DIR%\nssm.exe" install "%SERVICE_NAME%" powershell.exe "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\WazuhPerformance\service_runner.ps1"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" DisplayName "Wazuh Performance Monitor"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Description "Collects Windows performance metrics for Wazuh monitoring (v2 Multi-Drive)"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStdout "%LOG_DIR%\service_stdout.log"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStderr "%LOG_DIR%\service_stderr.log"

REM Start the service
echo Starting service...
"%INSTALL_DIR%\nssm.exe" start "%SERVICE_NAME%"

echo.
echo === Installation Complete (v2 - Multi-Drive) ===
echo Service: %SERVICE_NAME%
echo Install Directory: %INSTALL_DIR%
echo Log Directory: %LOG_DIR%
echo Performance Logs: performance_YYYY-MM-DD.json
echo Error Logs: performance_errors_YYYY-MM-DD.json
echo Service Logs: service_stdout.log, service_stderr.log
echo.
echo Wazuh Configuration:
echo ^<localfile^>
echo   ^<log_format^>json^</log_format^>
echo   ^<location^>C:\WazuhPerformance\logs\performance_*.json^</location^>
echo ^</localfile^>
echo.
echo Service is running and collecting data every 60 seconds.
echo Log rotation: Automatically removes logs older than 7 days.
echo.
echo NEW in v2:
echo - Monitors ALL fixed drives (C:, D:, E:, etc.)
echo - disk_highest_percent: Highest usage across all drives
echo - disk_alert_drive: Which drive has highest usage
echo - Individual drive metrics: disk_c_*, disk_d_*, etc.
pause
