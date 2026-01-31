# Wazuh Windows Performance Monitor

A Windows performance monitoring solution integrated with Wazuh SIEM for real-time system metrics collection and alerting.

## Features

- **Real-time Monitoring**: Collects CPU, Memory, and Disk metrics every 60 seconds
- **Wazuh Integration**: JSON formatted logs compatible with Wazuh's JSON decoder
- **High Usage Alerts**: Automatic alerts when CPU, Memory, or Disk usage exceeds 70%
- **Windows Service**: Runs as a background Windows service using NSSM
- **Auto Log Rotation**: Automatically removes logs older than 7 days

## Metrics Collected

| Category | Fields |
|----------|--------|
| **System** | hostname, domain, os_version, uptime_hours |
| **CPU** | cpu_total_core, cpu_used_core, cpu_free_core, cpu_used_percent |
| **Memory** | memory_total_gb, memory_used_gb, memory_free_gb, memory_used_percent |
| **Disk** | disk_total_gb, disk_used_gb, disk_free_gb, disk_used_percent |
| **Network** | network_adapters_active |

## Sample Log Output

```json
{
  "wazuhlogtype": "wazuhperformance",
  "log_timestamp": "2026-01-31T17:23:28.649Z",
  "hostname": "DESKTOP-L1LC85P",
  "domain": "AD",
  "os_version": "Microsoft Windows 10 Pro",
  "cpu_total_core": "12",
  "cpu_used_core": "0",
  "cpu_free_core": "12",
  "cpu_used_percent": "2",
  "memory_total_gb": "16",
  "memory_used_gb": "6",
  "memory_free_gb": "10",
  "memory_used_percent": "39",
  "disk_total_gb": "280",
  "disk_used_gb": "258",
  "disk_free_gb": "22",
  "disk_used_percent": "92",
  "network_adapters_active": "2",
  "uptime_hours": "56"
}
```

## Installation

### Step 1: Install on Windows Agent

1. Download `install-win-performance-monitor.bat`
2. Run as **Administrator**
3. The script will:
   - Download NSSM (Non-Sucking Service Manager)
   - Create performance monitoring scripts
   - Install and start the Windows service

```batch
# Run as Administrator
install-win-performance-monitor.bat
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

  <!-- High Disk Usage Alert (70-100%) -->
  <rule id="100903" level="10">
    <if_sid>100900</if_sid>
    <field name="disk_used_percent">^7\d|^8\d|^9\d|^100</field>
    <description>High Disk usage $(disk_used_percent)% detected on $(hostname)</description>
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
| 100903 | 10 | Disk >= 70% | High Disk usage alert |

## File Structure

```
C:\WazuhPerformance\
├── nssm.exe                    # Service manager
├── performance_monitor.ps1     # Main monitoring script
├── service_runner.ps1          # Service wrapper script
└── logs\
    ├── performance_YYYY-MM-DD.json    # Daily performance logs
    ├── performance_errors_YYYY-MM-DD.json  # Error logs
    ├── service_stdout.log      # Service output
    └── service_stderr.log      # Service errors
```

## Testing

### Test with wazuh-logtest

```bash
# On Wazuh manager
/var/ossec/bin/wazuh-logtest
```

Paste a sample log:
```json
{"wazuhlogtype":"wazuhperformance","log_timestamp":"2026-01-31T17:23:28.649Z","hostname":"DESKTOP-L1LC85P","domain":"AD","os_version":"Microsoft Windows 10 Pro","cpu_total_core":"12","cpu_used_core":"0","cpu_free_core":"12","cpu_used_percent":"2","memory_total_gb":"16","memory_used_gb":"6","memory_free_gb":"10","memory_used_percent":"39","disk_total_gb":"280","disk_used_gb":"258","disk_free_gb":"22","disk_used_percent":"92","network_adapters_active":"2","uptime_hours":"56"}
```

Expected output for disk alert (92%):
```
**Phase 3: Completed filtering (rules).
    id: '100903'
    level: '10'
    description: 'High Disk usage 92% detected on DESKTOP-L1LC85P'
```

## Uninstallation

Run as Administrator:
```batch
uninstall-win-performance-monitor.bat
```

Don't forget to remove the `<localfile>` configuration from `ossec.conf`.

## Troubleshooting

### Service not starting
```batch
# Check service status
sc query WazuhPerformanceMonitor

# Check logs
type C:\WazuhPerformance\logs\service_stderr.log
```

### Logs not appearing in Wazuh
1. Verify agent configuration has the `<localfile>` entry
2. Restart Wazuh agent
3. Check agent logs: `C:\Program Files (x86)\ossec-agent\ossec.log`

### Rules not triggering
1. Verify rules are in `/var/ossec/etc/rules/local_rules.xml`
2. Restart Wazuh manager: `systemctl restart wazuh-manager`
3. Test with `wazuh-logtest`

## Requirements

- Windows 7/Server 2008 R2 or later
- PowerShell 3.0 or later
- Administrator privileges for installation
- Wazuh Agent 4.x installed

## License

MIT License

## Author

Created for Wazuh SIEM integration
