# Midnight Node Health Check Script

A monitoring script for Midnight validator node that checks node synchronization status and reports health metrics to Healthchecks.io.

## Features

- 🔍 **Block Monitoring**: Tracks latest and finalized block numbers
- 📊 **Sync Status**: Calculates synchronization percentage and block lag
- 🚨 **Health Alerts**: Sends success/failure pings to Healthchecks.io
- 📝 **Logging**: Timestamp-based logging with status indicators
- ⚡ **Error Handling**: Robust error handling and validation
- 🔧 **Configurable**: Easy configuration via environment variables

## Prerequisites

Install required dependencies on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install curl jq gawk
```

## Configuration

### 1. Update Health Check URL

**IMPORTANT:** You must update the health check URL before using this script.

Edit the script and replace the `PING_BASE` URL on line 9:

```bash
readonly PING_BASE="https://hc-ping.com/YOUR-UNIQUE-HEALTHCHECK-ID"
```

Replace `YOUR-UNIQUE-HEALTHCHECK-ID` with your Healthchecks.io check ID.

### 2. Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RPC_URL` | `http://127.0.0.1:9944` | Node RPC endpoint |
| `MAX_ALLOWED_GAP` | `25` | Maximum allowed block gap before marking unhealthy |
| `NODE_ID` | `midnight-validator-1` | Unique identifier for your node |
| `TIMEOUT` | `10` | HTTP request timeout in seconds |
| `LOG_FILE` | `./healthchecks.log` | Path to log file |

## Installation

1. **Download the script:**
```bash
wget https://raw.githubusercontent.com/Midnight-Scripts/Midnight-Node-Health-Check-Script/refs/heads/main/midnight-healthcheck.sh
chmod +x midnight-healthcheck.sh
```

2. **Update the health check URL** (see Configuration section above)

3. **Test the script:**
```bash
./midnight-healthcheck.sh
```

## Setting Up Cron Job

To run the health check every minute, set up a cron job:

### 1. Open your crontab:
```bash
crontab -e
```

### 2. Add this line to run every minute:
```bash
* * * * * /path/to/midnight-healthcheck.sh
```

### 3. Verify cron job is working:
```bash
# Check if cron service is running
sudo systemctl status cron

# View cron logs
sudo tail -f /var/log/syslog | grep CRON
```

## Usage

### Manual Run
```bash
./midnight-healthcheck.sh
```

**Note:** The script automatically creates a log file (`healthchecks.log`) in the same directory where the script is located. This log file contains timestamps and status indicators (✅ for success, ❌ for failure, 💥 for errors).

## Expected Output

**Healthy Node:**
```
✅ Node is healthy
Node: midnight-validator-1
Timestamp: 2024-01-15 10:30:45 UTC
Latest Block: 12345
Finalized Block: 12320
Sync Percentage: 99.80%
Block Lag: 25 blocks
Status: HEALTHY
```

**Unhealthy Node:**
```
❌ Node lag too high!
Node: midnight-validator-1
Timestamp: 2024-01-15 10:30:45 UTC
Latest Block: 12345
Finalized Block: 12280
Sync Percentage: 99.47%
Block Lag: 65 blocks
Status: UNHEALTHY
```

## Monitoring Setup

### Healthchecks.io Configuration

1. Create account at [healthchecks.io](https://healthchecks.io/)
2. Create a new check with these settings:
   - **Period**: 5 minutes
   - **Grace Time**: 1 minute
3. Copy the ping URL
4. Update the `PING_BASE` variable in the script

The script sends different HTTP requests for success/failure:
- **Success**: `POST` to `$PING_BASE`
- **Failure**: `POST` to `$PING_BASE/fail`

## Troubleshooting

### Common Issues

**1. Permission Denied:**
```bash
chmod +x midnight-healthcheck.sh
```

**2. Dependencies Missing:**
```bash
which curl jq awk
```

**3. RPC Connection Failed:**
- Verify your node is running
- Check the RPC URL is correct
- Ensure firewall allows connections

**4. Cron Job Not Running:**
```bash
sudo systemctl status cron
sudo journalctl -u cron
```

### Log Analysis

View recent health check logs:
```bash
tail -f healthchecks.log
```

Check for errors:
```bash
grep ERROR healthchecks.log
``` 
