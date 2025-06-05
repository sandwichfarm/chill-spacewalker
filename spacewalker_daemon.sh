#!/bin/bash

# Simple bash-based SpaceWalker daemon
# Polls for VITURE connection every 3 seconds

DAEMON_NAME="spacewalker_daemon"
LOCK_FILE="/tmp/spacewalker_daemon.lock"
LOG_FILE="/tmp/spacewalker_daemon.log"
CONTROL_SCRIPT="/Users/sandwich/Develop/better-spacewalker/spacewalker_control.sh"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Check if another instance is running
check_single_instance() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log "Another instance is already running (PID: $pid). Exiting."
            exit 1
        else
            log "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # Create lock file
    echo $$ > "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    log "Daemon shutting down..."
    rm -f "$LOCK_FILE"
    exit 0
}

# Setup signal handlers
trap cleanup SIGTERM SIGINT EXIT

# Check if VITURE USB device is connected
is_viture_usb_connected() {
    ioreg -r -d0 -c IOUSBDevice 2>/dev/null | grep -q "VITURE Pro XR Glasses"
}

# Check if VITURE display is listed and online
is_viture_display_connected() {
    local display_output=$(system_profiler SPDisplaysDataType 2>/dev/null)
    echo "$display_output" | grep -q "VITURE" && echo "$display_output" | grep -q "Online: Yes"
}

# Check overall connection status
is_viture_connected() {
    is_viture_usb_connected && is_viture_display_connected
}

# Launch SpaceWalker with optimal settings
launch_spacewalker() {
    log "Launching SpaceWalker with 3-wide layout @ 120Hz"
    
    if [ ! -f "$CONTROL_SCRIPT" ]; then
        log "ERROR: Control script not found at $CONTROL_SCRIPT"
        return 1
    fi
    
    # Launch with optimal settings
    "$CONTROL_SCRIPT" start threewide 120hz >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✓ SpaceWalker launched successfully"
    else
        log "✗ Failed to launch SpaceWalker"
    fi
}

# Stop SpaceWalker
stop_spacewalker() {
    log "Stopping SpaceWalker"
    
    if [ ! -f "$CONTROL_SCRIPT" ]; then
        log "ERROR: Control script not found at $CONTROL_SCRIPT"
        return 1
    fi
    
    "$CONTROL_SCRIPT" stop >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✓ SpaceWalker stopped successfully"
    else
        log "✗ Failed to stop SpaceWalker"
    fi
}

# Main daemon loop
main_loop() {
    local last_state=false
    local current_state
    
    # Check initial state
    if is_viture_connected; then
        log "VITURE glasses detected on startup"
        launch_spacewalker
        last_state=true
    else
        log "No VITURE glasses detected on startup"
        last_state=false
    fi
    
    # Main polling loop
    while true; do
        # Check current connection state
        if is_viture_connected; then
            current_state=true
        else
            current_state=false
        fi
        
        # Detect state change
        if [ "$current_state" != "$last_state" ]; then
            if [ "$current_state" = true ]; then
                log "VITURE glasses CONNECTED"
                launch_spacewalker
            else
                log "VITURE glasses DISCONNECTED"
                stop_spacewalker
            fi
            
            last_state=$current_state
        fi
        
        # Sleep for 3 seconds before next check
        sleep 3
    done
}

# Start daemon
log "=== SpaceWalker Daemon Starting ==="
log "PID: $$"
log "Lock file: $LOCK_FILE"
log "Log file: $LOG_FILE"
log "Control script: $CONTROL_SCRIPT"

# Check for single instance
check_single_instance

# Verify control script exists
if [ ! -f "$CONTROL_SCRIPT" ]; then
    log "ERROR: Control script not found at $CONTROL_SCRIPT"
    log "Please ensure spacewalker_control.sh exists in the project directory"
    exit 1
fi

log "Starting main daemon loop..."
main_loop