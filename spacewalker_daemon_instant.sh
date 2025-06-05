#!/bin/bash

# SpaceWalker Instant Daemon
# Keeps SpaceWalker always running, instantly clicks buttons

DAEMON_NAME="spacewalker_daemon_instant"
LOCK_FILE="/tmp/spacewalker_daemon_instant.lock"
LOG_FILE="/tmp/spacewalker_daemon_instant.log"

# Ultra-fast polling - 0.5 seconds
POLL_INTERVAL=0.5

# Logging
log() {
    echo "[$(date '+%H:%M:%S.%3N')] $1" | tee -a "$LOG_FILE"
}

# Single instance check
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "Daemon already running (PID: $pid)"
        exit 1
    fi
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"

# Cleanup
cleanup() {
    log "Daemon shutting down"
    rm -f "$LOCK_FILE"
    # Don't stop SpaceWalker - keep it running!
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Ensure SpaceWalker is running and configured
ensure_spacewalker() {
    # Set config
    defaults write com.viture.spacewalker vtLayoutType -int 2
    defaults write com.viture.spacewalker N6PDisplayModeRaw -int 52
    defaults write com.viture.spacewalker isExtendMode -int 1
    defaults write com.viture.spacewalker reduceMotionBlur -int 1
    
    # Launch if not running
    if ! pgrep -f "SpaceWalker" > /dev/null; then
        log "Launching SpaceWalker (persistent mode)"
        osascript -e 'tell application "SpaceWalker" to launch' 2>/dev/null || true
        sleep 1
    fi
}

# Instant button click
click_if_needed() {
    osascript << 'EOF' 2>/dev/null || true
tell application "System Events"
    if exists process "SpaceWalker" then
        tell process "SpaceWalker"
            -- Keep minimized
            set visible to false
            
            if exists window 1 then
                -- Check for Launch button
                if exists button "Launch SpaceWalker" of window 1 then
                    click button "Launch SpaceWalker" of window 1
                    
                    -- Minimize after click
                    try
                        set miniaturized of window 1 to true
                    end try
                    
                    return "clicked"
                end if
            end if
        end tell
    end if
end tell
return "no_action"
EOF
}

# Main monitoring loop
log "=== Instant SpaceWalker Daemon Started ==="
log "Keeping SpaceWalker running for instant response"

ensure_spacewalker

last_usb_state="unknown"
glasses_connected=false

while true; do
    # Check USB only (fastest)
    if ioreg -r -d0 -c IOUSBDevice 2>/dev/null | grep -q "VITURE Pro XR Glasses"; then
        if [ "$glasses_connected" = false ]; then
            log "Glasses connected - checking for button"
            glasses_connected=true
            
            # Quick delay for UI
            sleep 0.2
            
            # Try to click immediately
            result=$(click_if_needed)
            if [ "$result" = "clicked" ]; then
                log "✓ Instantly clicked Launch button"
            else
                log "Button not found (may already be in session)"
            fi
        fi
    else
        if [ "$glasses_connected" = true ]; then
            log "Glasses disconnected"
            glasses_connected=false
            # SpaceWalker stays running!
        fi
    fi
    
    sleep $POLL_INTERVAL
done