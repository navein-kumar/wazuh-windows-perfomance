# Wazuh Windows Performance Monitor - v2 (Multi-Drive Support)

A Windows performance monitoring solution integrated with Wazuh SIEM for real-time system metrics collection and alerting. **v2 adds support for multiple drives** - perfect for Windows File Servers.

## What's New in v2

- **Multi-Drive Monitoring**: Automatically detects and monitors ALL fixed drives (C:, D:, E:, etc.)
- **Smart Alerting**: `disk_highest_percent` field tracks the highest usage across all drives
- **Drive Identification**: `disk_alert_drive` tells you which drive has the highest usage
- **Individual Drive Metrics**: Each drive gets its own fields (disk_c_*, disk_d_*, etc.)

## Features

- **Real-time Monitoring**: Collects CPU, Memory, and ALL Disk metrics every 60 seconds
- **Wazuh Integration**: JSON formatted logs compatible with Wazuh's JSON decoder
- **High Usage Alerts**: Automatic alerts when CPU, Memory, or ANY Disk exceeds 70%
- **Windows Service**: Runs as a background Windows service using NSSM
- **Auto Log Rotation**: Automatically removes logs older than 7 days

## Metrics Collected

| Category | Fields |
|----------|--------|
| **System** | hostname, domain, os_version, uptime_hours |
| **CPU** | cpu_total_core, cpu_used_core, cpu_free_core, cpu_used_percent |
| **Memory** | memory_total_gb, memory_used_gb, memory_free_gb, memory_used_percent |
| **Disk Summary** | disk_highest_percent, disk_alert_drive, disk_count |
| **Per Drive** | disk_X_total_gb, disk_X_used_gb, disk_X_free_gb, disk_X_used_percent |
| **Network** | network_adapters_active |

## Sample Log Output (File Server with 3 Drives)

```json
{
  "wazuhlogtype": "wazuhperformance",
  "log_timestamp": "2026-01-31T18:00:00.000Z",
  "hostname": "FILESERVER01",
  "domain": "AD",
  "os_version": "Microsoft Windows Server 2019 Standard",
  "cpu_total_core": "8",
  "cpu_used_core": "1",
  "cpu_free_core": "7",
  "cpu_used_percent": "12",
  "memory_total_gb": "32",
  "memory_used_gb": "18",
  "memory_free_gb": "14",
  "memory_used_percent": "56",
  "disk_highest_percent": "85",
  "disk_alert_drive": "D",
  "disk_count": "3",
  "network_adapters_active": "2",
  "uptime_hours": "720",
  "disk_c_total_gb": "100",
  "disk_c_used_gb": "45",
  "disk_c_free_gb": "55",
  "disk_c_used_percent": "45",
  "disk_d_total_gb": "500",
  "disk_d_used_gb": "425",
  "disk_d_free_gb": "75",
  "disk_d_used_percent": "85",
  "disk_e_total_gb": "1000",
  "disk_e_used_gb": "600",
  "disk_e_free_gb": "400",
  "disk_e_used_percent": "60"
}
```

In this example:
- **D: drive** has the highest usage at **85%**
- Alert will trigger because `disk_highest_percent` is 85% (>70%)
- Alert description will show: "High Disk usage 85% on drive D: detected on FILESERVER01"

## Installation

### Step 1: Install on Windows Agent

1. Download `install-win-performance-monitor-v2.bat`
2. Run as **Administrator**
3. The script will:
   - Download NSSM (Non-Sucking Service Manager)
   - Create performance monitoring scripts
   - Install and start the Windows service

```batch
# Run as Administrator
install-win-performance-monitor-v2.bat
```

### Step 2: Configure Wazuh Agent

Add the following to your Wazuh agent configuration file:

**Location:** `C:\Program Files (x86)\ossec-agent\ossec.conf`

```xml
<localfile>
  <log_format>json</log_format>
  <location>C:\WazuhPerformance\logs\performance_*.json</location>
</localfile>
```

Restart the Wazuh agent:
```batch
net stop WazuhSvc
net start WazuhSvc
```

### Step 3: Add Wazuh Rules

Add the following rules to your Wazuh manager:

**Location:** `/var/ossec/etc/rules/local_rules.xml`

```xml
<group name="windows_performance,performance_monitor">

  <!-- Base rule for Windows performance data -->
  <rule id="100900" level="3">
    <decoded_as>json</decoded_as>
    <field name="wazuhlogtype">wazuhperformance</field>
    <description>Windows performance metrics collected on $(hostname)</description>
  </rule>

  <!-- High CPU Usage Alert (70-100%) -->
  <rule id="100901" level="10">
    <if_sid>100900</if_sid>
    <field name="cpu_used_percent">^7\d|^8\d|^9\d|^100</field>
    <description>High CPU usage $(cpu_used_percent)% detected on $(hostname)</description>
  </rule>

  <!-- High Memory Usage Alert (70-100%) -->
  <rule id="100902" level="10">
    <if_sid>100900</if_sid>
    <field name="memory_used_percent">^7\d|^8\d|^9\d|^100</field>
    <description>High Memory usage $(memory_used_percent)% detected on $(hostname)</description>
  </rule>

  <!-- High Disk Usage Alert - ANY Drive (70-100%) -->
  <rule id="100903" level="10">
    <if_sid>100900</if_sid>
    <field name="disk_highest_percent">^7\d|^8\d|^9\d|^100</field>
    <description>High Disk usage $(disk_highest_percent)% on drive $(disk_alert_drive): detected on $(hostname)</description>
  </rule>

</group>
```

Restart Wazuh manager:
```bash
systemctl restart wazuh-manager
```

## Alert Rules

| Rule ID | Level | Trigger | Description |
|---------|-------|---------|-------------|
| 100900 | 3 | All logs | Base rule for performance metrics |
| 100901 | 10 | CPU >= 70% | High CPU usage alert |
| 100902 | 10 | Memory >= 70% | High Memory usage alert |
| 100903 | 10 | **ANY Disk** >= 70% | High Disk usage alert (shows which drive) |

## How Multi-Drive Alerting Works

1. Script scans **all fixed drives** (DriveType=3)
2. Calculates usage percentage for each drive
3. Stores the **highest** percentage in `disk_highest_percent`
4. Stores which drive has highest usage in `disk_alert_drive`
5. Wazuh rule matches on `disk_highest_percent` field
6. Alert description shows both percentage AND drive letter

**Example Alert:**
```
High Disk usage 85% on drive D: detected on FILESERVER01
```

## Testing

### Test with wazuh-logtest

```bash
# On Wazuh manager
/var/ossec/bin/wazuh-logtest
```

Paste a sample log with high D: drive usage:
```json
{"wazuhlogtype":"wazuhperformance","log_timestamp":"2026-01-31T18:00:00.000Z","hostname":"FILESERVER01","domain":"AD","os_version":"Microsoft Windows Server 2019 Standard","cpu_total_core":"8","cpu_used_core":"1","cpu_free_core":"7","cpu_used_percent":"12","memory_total_gb":"32","memory_used_gb":"18","memory_free_gb":"14","memory_used_percent":"56","disk_highest_percent":"85","disk_alert_drive":"D","disk_count":"3","network_adapters_active":"2","uptime_hours":"720","disk_c_total_gb":"100","disk_c_used_gb":"45","disk_c_free_gb":"55","disk_c_used_percent":"45","disk_d_total_gb":"500","disk_d_used_gb":"425","disk_d_free_gb":"75","disk_d_used_percent":"85","disk_e_total_gb":"1000","disk_e_used_gb":"600","disk_e_free_gb":"400","disk_e_used_percent":"60"}
```

Expected output:
```
**Phase 3: Completed filtering (rules).
    id: '100903'
    level: '10'
    description: 'High Disk usage 85% on drive D: detected on FILESERVER01'
```

## Comparison: v1 vs v2

| Feature | v1 | v2 |
|---------|-----|-----|
| C: Drive Monitoring | ✅ | ✅ |
| D:, E:, etc. Monitoring | ❌ | ✅ |
| Multi-Drive Alert | ❌ | ✅ |
| Drive Identification | ❌ | ✅ |
| Per-Drive Metrics | ❌ | ✅ |
| File Server Support | ❌ | ✅ |

## Requirements

- Windows 7/Server 2008 R2 or later
- PowerShell 3.0 or later
- Administrator privileges for installation
- Wazuh Agent 4.x installed

## License

MIT License

## Author

Created for Wazuh SIEM integration
