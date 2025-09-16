# Windows Performance Monitor for Wazuh
$logDir = "C:\WazuhPerformance\logs"
$today = Get-Date -Format "yyyy-MM-dd"
$logFile = "$logDir\performance_$today.json"

try {
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Get CPU
    $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
    $cpuPercent = if ($cpu.LoadPercentage) { $cpu.LoadPercentage } else { 0 }

    # Get Memory
    $memory = Get-WmiObject -Class Win32_OperatingSystem
    $memTotalKB = $memory.TotalVisibleMemorySize
    $memFreeKB = $memory.FreePhysicalMemory
    $memUsedKB = $memTotalKB - $memFreeKB
    $memUsedPercent = [math]::Round(($memUsedKB / $memTotalKB) * 100, 2)

    # Get Disk
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotalGB = [math]::Round($disk.Size / 1GB, 2)
    $diskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $diskUsedGB = $diskTotalGB - $diskFreeGB
    $diskUsedPercent = [math]::Round(($diskUsedGB / $diskTotalGB) * 100, 2)

    # Create JSON
    $perfData = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        hostname = $env:COMPUTERNAME
        domain = $env:USERDOMAIN
        cpu_percent = $cpuPercent
        memory_total_gb = [math]::Round($memTotalKB / 1MB, 2)
        memory_used_gb = [math]::Round($memUsedKB / 1MB, 2)
        memory_free_gb = [math]::Round($memFreeKB / 1MB, 2)
        memory_used_percent = $memUsedPercent
        disk_total_gb = $diskTotalGB
        disk_used_gb = $diskUsedGB
        disk_free_gb = $diskFreeGB
        disk_used_percent = $diskUsedPercent
    }

    # Write JSON to file
    $json = $perfData | ConvertTo-Json -Compress
    $json | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Clean old logs (older than 7 days)
    if ((Get-Date).Hour -eq 0 -and (Get-Date).Minute -eq 0) {
        $cutoffDate = (Get-Date).AddDays(-7)
        Get-ChildItem -Path $logDir -Filter "performance_*.json" | Where-Object { $_.LastWriteTime -lt $cutoffDate } | Remove-Item -Force
    }

} catch {
    # Silent error handling
}
