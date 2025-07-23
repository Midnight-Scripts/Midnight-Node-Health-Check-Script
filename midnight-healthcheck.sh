#!/bin/bash

# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration - Consider moving to external config file
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PING_BASE="https://hc-ping.com/b09f7514-98d1-4ee8-a58b-a9573d256854"
readonly RPC_URL="${RPC_URL:-http://127.0.0.1:9944}"
readonly MAX_ALLOWED_GAP="${MAX_ALLOWED_GAP:-25}"
readonly NODE_ID="${NODE_ID:-midnight-validator-1}"
readonly TIMEOUT="${TIMEOUT:-10}"
readonly LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/healthchecks.log}"

# Logging function
log() {
    local level="$1"
    shift
    
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || return 1
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# JSON-RPC call function with error handling
rpc_call() {
    local method="$1"
    local params="$2"
    local response
    
    response=$(curl -s --max-time "$TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":$params}" \
        "$RPC_URL" 2>/dev/null) || {
        error_exit "Failed to connect to RPC endpoint: $RPC_URL"
    }
    
    # Check for JSON-RPC errors
    local error
    error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error" ]]; then
        error_exit "RPC Error: $error"
    fi
    
    echo "$response"
}

# Validate dependencies
check_dependencies() {
    local deps=("curl" "jq" "awk")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_exit "Required dependency '$dep' not found"
        fi
    done
}

# Convert hex to decimal with validation
hex_to_decimal() {
    local hex_value="$1"
    
    # Remove 0x prefix if present
    hex_value="${hex_value#0x}"
    
    # Validate hex format
    if [[ ! "$hex_value" =~ ^[0-9a-fA-F]+$ ]]; then
        error_exit "Invalid hex value: $hex_value"
    fi
    
    echo $((16#$hex_value))
}

# Get latest block number
get_latest_block() {
    local response
    response=$(rpc_call "chain_getHeader" "[]")
    
    local latest_hex
    latest_hex=$(echo "$response" | jq -r '.result.number // empty')
    
    if [[ -z "$latest_hex" ]]; then
        error_exit "Failed to get latest block number"
    fi
    
    hex_to_decimal "$latest_hex"
}

# Get finalized block number
get_finalized_block() {
    local finalized_hash
    finalized_hash=$(rpc_call "chain_getFinalizedHead" "[]" | jq -r '.result // empty')
    
    if [[ -z "$finalized_hash" ]]; then
        error_exit "Failed to get finalized head hash"
    fi
    
    local response
    response=$(rpc_call "chain_getHeader" "[\"$finalized_hash\"]")
    
    local finalized_hex
    finalized_hex=$(echo "$response" | jq -r '.result.number // empty')
    
    if [[ -z "$finalized_hex" ]]; then
        error_exit "Failed to get finalized block number"
    fi
    
    hex_to_decimal "$finalized_hex"
}

# Send health check ping
send_ping() {
    local endpoint="$1"
    local message="$2"
    local user_agent="$3"
    
    if curl -fsS --max-time "$TIMEOUT" \
        -A "$user_agent" \
        -X POST \
        --data "$message" \
        "$endpoint" &>/dev/null; then
        return 0
    else
        log "ERROR" "Failed to send ping to $endpoint"
        return 1
    fi
}

# Calculate sync percentage with better precision
calculate_sync_percentage() {
    local finalized="$1"
    local latest="$2"
    
    if [[ "$latest" -eq 0 ]]; then
        echo "0.00"
        return
    fi
    
    awk "BEGIN{printf \"%.2f\", ($finalized / $latest) * 100}"
}

# Generate status message
generate_status_message() {
    local node_id="$1"
    local latest="$2"
    local finalized="$3"
    local sync_pct="$4"
    local gap="$5"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')
    
    cat <<EOF
Node: $node_id
Timestamp: $timestamp
Latest Block: $latest
Finalized Block: $finalized
Sync Percentage: $sync_pct%
Block Lag: $gap blocks
Status: $([ "$gap" -le "$MAX_ALLOWED_GAP" ] && echo "HEALTHY" || echo "UNHEALTHY")
EOF
}

# Main monitoring logic
main() {
    log "INFO" "Starting node monitoring for $NODE_ID"
    
    # Check dependencies
    check_dependencies
    
    # Get block numbers
    log "INFO" "Fetching latest block..."
    local latest_block
    latest_block=$(get_latest_block)
    
    log "INFO" "Fetching finalized block..."
    local finalized_block
    finalized_block=$(get_finalized_block)
    
    # Calculate metrics
    local gap=$((latest_block - finalized_block))
    local sync_percentage
    sync_percentage=$(calculate_sync_percentage "$finalized_block" "$latest_block")
    
    # Generate status message
    local status_message
    status_message=$(generate_status_message "$NODE_ID" "$latest_block" "$finalized_block" "$sync_percentage" "$gap")
    
    # Determine health status and send appropriate ping
    if [[ "$gap" -ge 0 ]] && [[ "$gap" -le "$MAX_ALLOWED_GAP" ]]; then
        if send_ping "$PING_BASE" "$status_message" "$NODE_ID"; then
            log "INFO" "✅ Health check passed - ping sent successfully"
            echo -e "✅ Node is healthy\n$status_message"
        else
            error_exit "Failed to send success ping"
        fi
    else
        if send_ping "$PING_BASE/fail" "$status_message" "$NODE_ID"; then
            log "WARN" "❌ Health check failed - failure ping sent"
        else
            log "ERROR" "Failed to send failure ping"
        fi
        echo -e "❌ Node lag too high!\n$status_message"
        exit 1
    fi
}

# Trap signals for clean exit
trap 'log "INFO" "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"
