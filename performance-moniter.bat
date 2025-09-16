@echo off

REM Variables
set NSSM_URL=https://github.com/navein-kumar/wazuh-Netstat-Powershell/raw/refs/heads/main/nssm.exe
set INSTALL_DIR=C:\performance
set SERVICE_NAME=WazuhPerformanceMonitor

echo === Complete Performance Monitor Installation ===

REM Stop and remove existing
sc stop "%SERVICE_NAME%" >nul 2>&1
if exist "%INSTALL_DIR%\nssm.exe" (
    "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm >nul 2>&1
)
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"

REM Create directory and download
mkdir "%INSTALL_DIR%"
powershell -Command "Invoke-WebRequest -Uri '%NSSM_URL%' -OutFile '%INSTALL_DIR%\nssm.exe'"

REM Create proper JSON performance script
(
echo $logDir = "C:\performance"
echo $today = Get-Date -Format "yyyy-MM-dd"
echo $logFile = "$logDir\performance_$today.json"
echo try {
echo     $cpu = Get-WmiObject -Class Win32_Processor ^| Select-Object -First 1
echo     $cpuLoad = if ^($cpu.LoadPercentage^) { $cpu.LoadPercentage } else { 0 }
echo     $memory = Get-WmiObject -Class Win32_OperatingSystem
echo     $memUsedPercent = [math]::Round^(^(^($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory^)/$memory.TotalVisibleMemorySize^) * 100, 2^)
echo     $disk = Get-WmiObject -Class Win32_LogicalDisk ^| Where-Object { $_.DeviceID -eq "C:" }
echo     $diskUsedPercent = if ^($disk^) { [math]::Round^(^(^($disk.Size - $disk.FreeSpace^) / $disk.Size^) * 100, 2^) } else { 0 }
echo     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo     $memTotalGb = [math]::Round^($memory.TotalVisibleMemorySize / 1MB, 2^)
echo     $memFreeGb = [math]::Round^($memory.FreePhysicalMemory / 1MB, 2^)
echo     $diskTotalGb = if ^($disk^) { [math]::Round^($disk.Size / 1GB, 2^) } else { 0 }
echo     $diskFreeGb = if ^($disk^) { [math]::Round^($disk.FreeSpace / 1GB, 2^) } else { 0 }
echo     $json = "{`"timestamp`":`"$timestamp`",`"hostname`":`"$env:COMPUTERNAME`",`"cpu_percent`":`"$cpuLoad`",`"memory_percent`":`"$memUsedPercent`",`"disk_percent`":`"$diskUsedPercent`",`"memory_total_gb`":`"$memTotalGb`",`"memory_free_gb`":`"$memFreeGb`",`"disk_total_gb`":`"$diskTotalGb`",`"disk_free_gb`":`"$diskFreeGb`"}"
echo     Add-Content -Path $logFile -Value $json
echo     $cutoffDate = ^(Get-Date^).AddDays^(-5^)
echo     Get-ChildItem -Path $logDir -Filter "performance_*.json" ^| Where-Object { $_.LastWriteTime -lt $cutoffDate } ^| Remove-Item -Force
echo } catch {
echo     $errorJson = "{`"timestamp`":`"$^(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'^)`",`"hostname`":`"$env:COMPUTERNAME`",`"error`":`"$^($_.Exception.Message^)`"}"
echo     Add-Content -Path $logFile -Value $errorJson
echo }
) > "%INSTALL_DIR%\performance_monitor.ps1"

REM Create service runner
(
echo while ^($true^) {
echo     ^& "C:\performance\performance_monitor.ps1"
echo     Start-Sleep -Seconds 60
echo }
) > "%INSTALL_DIR%\service_runner.ps1"

REM Install and start service
"%INSTALL_DIR%\nssm.exe" install "%SERVICE_NAME%" powershell.exe "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\performance\service_runner.ps1"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" DisplayName "Wazuh Performance Monitor"
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
"%INSTALL_DIR%\nssm.exe" start "%SERVICE_NAME%"

echo Complete! Service installed and running.
echo Files: C:\performance\performance_YYYY-MM-DD.json
echo Wazuh config: ^<location^>C:\performance\performance_*.json^</location^>
pause
