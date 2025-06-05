#!/bin/bash

# SpaceWalker FAST CLI Control Script
# Optimized for speed and transparency

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUNDLE_ID="com.viture.spacewalker"
BUTTON_CHECK_INTERVAL=0.1  # Check every 100ms
MAX_BUTTON_CHECKS=50       # Max 5 seconds of checking

# Configuration options
LAYOUT_SINGLE=0
LAYOUT_SIDE_BY_SIDE=1  
LAYOUT_THREE_WIDE=2

REFRESH_60HZ=20
REFRESH_120HZ=52

# Function to check if SpaceWalker is running
is_running() {
    pgrep -f "SpaceWalker" > /dev/null
}

# Function to set configuration FAST (no output)
set_config_fast() {
    local layout="$1"
    local refresh="$2"
    
    # Set layout
    case "$layout" in
        "single"|"0") defaults write "$BUNDLE_ID" vtLayoutType -int 0 ;;
        "sidebyside"|"1") defaults write "$BUNDLE_ID" vtLayoutType -int 1 ;;
        "threewide"|"2") defaults write "$BUNDLE_ID" vtLayoutType -int 2 ;;
    esac
    
    # Set refresh
    case "$refresh" in
        "60hz"|"60") defaults write "$BUNDLE_ID" N6PDisplayModeRaw -int 20 ;;
        "120hz"|"120"|"") defaults write "$BUNDLE_ID" N6PDisplayModeRaw -int 52 ;;
    esac
    
    # Set other optimal settings
    defaults write "$BUNDLE_ID" isExtendMode -int 1
    defaults write "$BUNDLE_ID" reduceMotionBlur -int 1
    defaults write "$BUNDLE_ID" autoTurnOffMainDisplay -int 1
}

# Function to minimize SpaceWalker window
minimize_spacewalker() {
    osascript << 'EOF' 2>/dev/null || true
tell application "System Events"
    tell process "SpaceWalker"
        try
            set miniaturized of window 1 to true
        on error
            -- Try alternate method
            keystroke "m" using command down
        end try
    end tell
end tell
EOF
}

# Function to hide SpaceWalker (even better than minimize)
hide_spacewalker() {
    osascript << 'EOF' 2>/dev/null || true
tell application "System Events"
    set visible of process "SpaceWalker" to false
end tell
EOF
}

# Function to continuously check for button and click immediately
fast_button_click() {
    local checks=0
    local button_clicked=false
    
    while [ $checks -lt $MAX_BUTTON_CHECKS ] && [ "$button_clicked" = false ]; do
        # Check if button exists and click it immediately
        osascript << 'EOF' 2>/dev/null && button_clicked=true || true
tell application "System Events"
    tell process "SpaceWalker"
        try
            if exists button "Launch SpaceWalker" of window 1 then
                click button "Launch SpaceWalker" of window 1
                return "clicked"
            end if
        end try
    end tell
end tell
EOF
        
        if [ "$button_clicked" = true ]; then
            break
        fi
        
        # Very short sleep for rapid checking
        sleep $BUTTON_CHECK_INTERVAL
        ((checks++))
    done
    
    return $([ "$button_clicked" = true ] && echo 0 || echo 1)
}

# Ultra-fast start function
start_spacewalker_ultra_fast() {
    # Set configuration before launching (faster)
    set_config_fast "threewide" "120hz"
    
    # If already running, just hide it and click button
    if is_running; then
        hide_spacewalker
        fast_button_click
        return 0
    fi
    
    # Launch minimized and in background
    osascript << 'EOF' 2>/dev/null &
tell application "SpaceWalker"
    launch
end tell

-- Immediately start checking for window
repeat 50 times
    tell application "System Events"
        if exists process "SpaceWalker" then
            tell process "SpaceWalker"
                -- Keep it invisible
                set visible to false
                
                -- Check for window and button
                if exists window 1 then
                    -- Minimize immediately
                    try
                        set miniaturized of window 1 to true
                    end try
                    
                    -- Click button if exists
                    if exists button "Launch SpaceWalker" of window 1 then
                        click button "Launch SpaceWalker" of window 1
                        exit repeat
                    end if
                end if
            end tell
        end if
    end tell
    delay 0.1
end repeat
EOF
    
    return 0
}

# Stealth mode - launch completely hidden
start_spacewalker_stealth() {
    # Set configuration
    set_config_fast "threewide" "120hz"
    
    # Launch hidden
    osascript << 'EOF' 2>/dev/null || true
tell application "SpaceWalker"
    launch
    set visible to false
end tell
EOF
    
    # Wait minimal time
    sleep 1
    
    # Click button while hidden
    osascript << 'EOF' 2>/dev/null || true
tell application "System Events"
    tell process "SpaceWalker"
        set visible to false
        try
            repeat 20 times
                if exists button "Launch SpaceWalker" of window 1 then
                    click button "Launch SpaceWalker" of window 1
                    exit repeat
                end if
                delay 0.1
            end repeat
        end try
    end tell
end tell
EOF
}

# Function to stop SpaceWalker gracefully and quietly
stop_spacewalker_quiet() {
    if ! is_running; then
        return 0
    fi
    
    # Hide first, then quit
    hide_spacewalker
    sleep 0.2
    
    osascript -e 'tell application "SpaceWalker" to quit' 2>/dev/null || true
    
    # Wait briefly for graceful quit
    local count=0
    while [ $count -lt 30 ] && is_running; do
        sleep 0.1
        ((count++))
    done
    
    # Force quit if needed (quietly)
    if is_running; then
        pkill -TERM -f "SpaceWalker" 2>/dev/null || true
    fi
}

# Main execution based on command
case "${1:-}" in
    "fast")
        start_spacewalker_ultra_fast
        ;;
    "stealth")
        start_spacewalker_stealth
        ;;
    "stop")
        stop_spacewalker_quiet
        ;;
    *)
        # Default: ultra-fast mode
        start_spacewalker_ultra_fast
        ;;
esac