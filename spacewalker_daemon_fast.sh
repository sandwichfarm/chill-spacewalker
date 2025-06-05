#!/bin/bash

# Ultra-Fast SpaceWalker Daemon
# Optimized for speed and transparency

DAEMON_NAME="spacewalker_daemon_fast"
LOCK_FILE="/tmp/spacewalker_daemon_fast.lock"
LOG_FILE="/tmp/spacewalker_daemon_fast.log"
CONTROL_SCRIPT="/Users/sandwich/Develop/better-spacewalker/spacewalker_control_fast.sh"

# Faster polling interval
POLL_INTERVAL=1.5  # Check every 1.5 seconds

# State tracking
LAST_STATE_FILE="/tmp/spacewalker_last_state"

# Logging function (minimal for speed)
log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if another instance is running
check_single_instance() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            exit 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE" "$LAST_STATE_FILE"
    "$CONTROL_SCRIPT" stop 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Fast detection using cached results
is_viture_connected_fast() {
    # Check USB first (fastest)
    if ! ioreg -r -d0 -c IOUSBDevice 2>/dev/null | grep -q "VITURE Pro XR Glasses"; then
        echo "false"
        return
    fi
    
    # If USB found, verify display (but cache result)
    local display_check_file="/tmp/viture_display_check"
    local current_time=$(date +%s)
    
    # Use cached display result if less than 5 seconds old
    if [ -f "$display_check_file" ]; then
        local file_time=$(stat -f %m "$display_check_file" 2>/dev/null || echo 0)
        local age=$((current_time - file_time))
        
        if [ $age -lt 5 ]; then
            cat "$display_check_file"
            return
        fi
    fi
    
    # Fresh display check
    if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "VITURE.*Online: Yes"; then
        echo "true" > "$display_check_file"
        echo "true"
    else
        echo "false" > "$display_check_file"
        echo "false"
    fi
}

# Load last state
get_last_state() {
    if [ -f "$LAST_STATE_FILE" ]; then
        cat "$LAST_STATE_FILE"
    else
        echo "unknown"
    fi
}

# Save current state
save_state() {
    echo "$1" > "$LAST_STATE_FILE"
}

# Main loop
main_loop() {
    log "Fast daemon started"
    
    # Initial state
    local last_state=$(get_last_state)
    local current_state
    
    while true; do
        # Fast detection
        if [ "$(is_viture_connected_fast)" = "true" ]; then
            current_state="connected"
        else
            current_state="disconnected"
        fi
        
        # Only act on state changes
        if [ "$current_state" != "$last_state" ]; then
            if [ "$current_state" = "connected" ]; then
                log "Glasses connected - launching (stealth mode)"
                "$CONTROL_SCRIPT" stealth &  # Launch in background
            else
                log "Glasses disconnected - stopping"
                "$CONTROL_SCRIPT" stop &     # Stop in background
            fi
            
            save_state "$current_state"
            last_state="$current_state"
        fi
        
        sleep $POLL_INTERVAL
    done
}

# Start daemon
check_single_instance
main_loop