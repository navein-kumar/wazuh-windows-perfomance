@echo off
setlocal enabledelayedexpansion

REM Variables
set NSSM_URL=https://github.com/navein-kumar/wazuh-Netstat-Powershell/raw/refs/heads/main/nssm.exe
set INSTALL_DIR=C:\WazuhPerformance
set SERVICE_NAME=WazuhPerformanceMonitor
set LOG_DIR=%INSTALL_DIR%\logs

echo === Wazuh Performance Monitor Installation ===

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
echo # Windows Performance Monitor for Wazuh - Complete Version
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
echo     try {
echo         $cpu = Get-WmiObject -Class Win32_Processor ^| Select-Object -First 1
echo         if ^($cpu.LoadPercentage^) {
echo             $cpuPercent = $cpu.LoadPercentage
echo         } else {
echo             # Fallback to performance counter
echo             $perfCounter = Get-Counter "\Processor^(_Total^)\%% Processor Time" -SampleInterval 1 -MaxSamples 1
echo             $cpuPercent = [math]::Round^($perfCounter.CounterSamples[0].CookedValue, 2^)
echo         }
echo     } catch {
echo         $cpuPercent = 0
echo     }
echo.
echo     # Get Memory information
echo     $memory = Get-WmiObject -Class Win32_OperatingSystem
echo     $memTotalKB = $memory.TotalVisibleMemorySize
echo     $memFreeKB = $memory.FreePhysicalMemory
echo     $memUsedKB = $memTotalKB - $memFreeKB
echo     $memUsedPercent = [math]::Round^(^($memUsedKB / $memTotalKB^) * 100, 2^)
echo.
echo     # Get Disk information for C: drive
echo     $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
echo     $diskTotalGB = [math]::Round^($disk.Size / 1GB, 2^)
echo     $diskFreeGB = [math]::Round^($disk.FreeSpace / 1GB, 2^)
echo     $diskUsedGB = $diskTotalGB - $diskFreeGB
echo     $diskUsedPercent = [math]::Round^(^($diskUsedGB / $diskTotalGB^) * 100, 2^)
echo.
echo     # Get Network adapters
echo     $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapter -Filter "NetConnectionStatus=2"
echo     $activeNetworkCount = ^($networkAdapters ^| Measure-Object^).Count
echo.
echo     # Get System uptime
echo     $bootTime = ^(Get-WmiObject Win32_OperatingSystem^).LastBootUpTime
echo     $bootTimeFormatted = [Management.ManagementDateTimeConverter]::ToDateTime^($bootTime^)
echo     $uptime = ^(Get-Date^) - $bootTimeFormatted
echo     $uptimeHours = [math]::Round^($uptime.TotalHours, 2^)
echo.
echo     # Create comprehensive performance object
echo     $perfData = @{
echo         timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
echo         hostname = $env:COMPUTERNAME
echo         domain = $env:USERDOMAIN
echo         os_version = $memory.Caption
echo         cpu_percent = $cpuPercent
echo         memory_total_gb = [math]::Round^($memTotalKB / 1MB, 2^)
echo         memory_used_gb = [math]::Round^($memUsedKB / 1MB, 2^)
echo         memory_free_gb = [math]::Round^($memFreeKB / 1MB, 2^)
echo         memory_used_percent = $memUsedPercent
echo         disk_total_gb = $diskTotalGB
echo         disk_used_gb = $diskUsedGB
echo         disk_free_gb = $diskFreeGB
echo         disk_used_percent = $diskUsedPercent
echo         network_adapters_active = $activeNetworkCount
echo         uptime_hours = $uptimeHours
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
echo             timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
echo             hostname = $env:COMPUTERNAME
echo             error = $_.Exception.Message
echo             error_type = "performance_collection_failed"
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
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Description "Collects Windows performance metrics for Wazuh monitoring"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStdout "%LOG_DIR%\service_stdout.log"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStderr "%LOG_DIR%\service_stderr.log"

REM Start the service
echo Starting service...
"%INSTALL_DIR%\nssm.exe" start "%SERVICE_NAME%"

echo.
echo === Installation Complete ===
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
pause
