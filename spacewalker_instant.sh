#!/bin/bash

# SpaceWalker Instant Control
# Keeps app running, just monitors and clicks buttons instantly

set -e

BUNDLE_ID="com.viture.spacewalker"
STATE_FILE="/tmp/spacewalker_instant_state"
LOG_FILE="/tmp/spacewalker_instant.log"

# Minimal logging
log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if SpaceWalker is running
is_running() {
    pgrep -f "SpaceWalker" > /dev/null
}

# Ensure SpaceWalker is configured and running
ensure_running() {
    # Set optimal config
    defaults write "$BUNDLE_ID" vtLayoutType -int 2        # Three wide
    defaults write "$BUNDLE_ID" N6PDisplayModeRaw -int 52  # 120Hz
    defaults write "$BUNDLE_ID" isExtendMode -int 1
    defaults write "$BUNDLE_ID" reduceMotionBlur -int 1
    defaults write "$BUNDLE_ID" autoTurnOffMainDisplay -int 1
    
    if ! is_running; then
        log "Starting SpaceWalker (will stay running)"
        # Launch minimized
        osascript << 'EOF' 2>/dev/null || true
tell application "SpaceWalker"
    launch
end tell
tell application "System Events"
    repeat 10 times
        if exists process "SpaceWalker" then
            tell process "SpaceWalker"
                set visible to false
                if exists window 1 then
                    try
                        set miniaturized of window 1 to true
                    end try
                end if
            end tell
            exit repeat
        end if
        delay 0.1
    end repeat
end tell
EOF
    fi
}

# Monitor for Launch button and click instantly
click_launch_button() {
    local clicked=false
    
    osascript << 'EOF' 2>/dev/null && clicked=true || true
tell application "System Events"
    tell process "SpaceWalker"
        if exists window 1 then
            if exists button "Launch SpaceWalker" of window 1 then
                -- Button exists, click it!
                click button "Launch SpaceWalker" of window 1
                
                -- Minimize after clicking
                try
                    set miniaturized of window 1 to true
                end try
                
                return "clicked"
            else
                -- No launch button, might already be in XR mode
                return "no_button"
            end if
        else
            return "no_window"
        end if
    end tell
end tell
EOF
    
    echo "$clicked"
}

# Check if we're in the XR session
is_in_xr_session() {
    # Check if the Launch button is NOT present (means we're in session)
    local result=$(osascript << 'EOF' 2>/dev/null || echo "error"
tell application "System Events"
    tell process "SpaceWalker"
        if exists window 1 then
            if exists button "Launch SpaceWalker" of window 1 then
                return "has_launch_button"
            else
                -- Check for other UI elements that indicate XR session
                set elementCount to count of UI elements of window 1
                if elementCount < 5 then
                    return "in_session"
                else
                    return "unknown"
                end if
            end if
        else
            return "no_window"
        end if
    end tell
end tell
EOF
)
    
    [ "$result" = "in_session" ] || [ "$result" = "no_window" ]
}

# Get current state
get_state() {
    if is_in_xr_session; then
        echo "xr_active"
    else
        echo "waiting_launch"
    fi
}

# Save state
save_state() {
    echo "$1" > "$STATE_FILE"
}

# Load state
load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

# Handle connection (instant response)
handle_connect() {
    log "Glasses connected - checking state"
    
    ensure_running
    
    # Wait minimal time for UI
    sleep 0.3
    
    local current_state=$(get_state)
    local last_state=$(load_state)
    
    if [ "$current_state" = "waiting_launch" ]; then
        log "Launch button available - clicking"
        click_launch_button
        save_state "xr_active"
    else
        log "Already in XR session"
        save_state "xr_active"
    fi
}

# Handle disconnection (just update state, don't close app)
handle_disconnect() {
    log "Glasses disconnected - XR session ended"
    save_state "waiting_launch"
    
    # The app stays running but returns to launch screen
    # No need to close it!
}

# Instant monitoring loop
monitor_instant() {
    ensure_running
    
    local last_connected=false
    
    while true; do
        # Ultra-fast USB check only
        if ioreg -r -d0 -c IOUSBDevice 2>/dev/null | grep -q "VITURE Pro XR Glasses"; then
            if [ "$last_connected" = false ]; then
                handle_connect
                last_connected=true
            fi
        else
            if [ "$last_connected" = true ]; then
                handle_disconnect
                last_connected=false
            fi
        fi
        
        # Even faster polling
        sleep 0.5
    done
}

# Main execution
case "${1:-}" in
    "start")
        handle_connect
        ;;
    "stop")
        handle_disconnect
        ;;
    "monitor")
        monitor_instant
        ;;
    *)
        # Default: ensure running and handle connection
        handle_connect
        ;;
esac