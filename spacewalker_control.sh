#!/bin/bash

# SpaceWalker CLI Control Script
# Bypasses GUI by directly manipulating preferences and using AppleScript

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUNDLE_ID="com.viture.spacewalker"

# Configuration options
LAYOUT_SINGLE=0
LAYOUT_SIDE_BY_SIDE=1  
LAYOUT_THREE_WIDE=2

REFRESH_60HZ=20
REFRESH_120HZ=52

usage() {
    echo "SpaceWalker CLI Control"
    echo "======================"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start [layout] [refresh]  - Start SpaceWalker with specific config"
    echo "  stop                      - Stop SpaceWalker"
    echo "  config [options]          - Set configuration without starting"
    echo "  status                    - Show current status and settings"
    echo "  reset                     - Reset to default settings"
    echo ""
    echo "Layout options:"
    echo "  single      - Single large display (vtLayoutType=0)"
    echo "  sidebyside  - Two displays side by side (vtLayoutType=1)" 
    echo "  threewide   - Three displays side by side (vtLayoutType=2)"
    echo ""
    echo "Refresh options:"
    echo "  60hz        - 60Hz refresh rate"
    echo "  120hz       - 120Hz refresh rate (default)"
    echo ""
    echo "Examples:"
    echo "  $0 start threewide 120hz"
    echo "  $0 start sidebyside"
    echo "  $0 config threewide 120hz"
    echo "  $0 stop"
}

# Function to check if SpaceWalker is running
is_running() {
    pgrep -f "SpaceWalker" > /dev/null
}

# Function to set configuration
set_config() {
    local layout="$1"
    local refresh="$2"
    
    echo -e "${BLUE}Configuring SpaceWalker...${NC}"
    
    # Map layout names to values
    case "$layout" in
        "single"|"0")
            layout_value=0
            echo "Setting layout: Single display"
            ;;
        "sidebyside"|"side"|"1")
            layout_value=1
            echo "Setting layout: Side by side"
            ;;
        "threewide"|"three"|"2")
            layout_value=2
            echo "Setting layout: Three wide"
            ;;
        "")
            echo "Keeping current layout"
            layout_value=""
            ;;
        *)
            echo -e "${RED}Invalid layout: $layout${NC}"
            echo "Valid options: single, sidebyside, threewide"
            return 1
            ;;
    esac
    
    # Map refresh names to values
    case "$refresh" in
        "60hz"|"60")
            refresh_value=20
            echo "Setting refresh: 60Hz"
            ;;
        "120hz"|"120"|"")
            refresh_value=52
            echo "Setting refresh: 120Hz"
            ;;
        *)
            echo -e "${RED}Invalid refresh rate: $refresh${NC}"
            echo "Valid options: 60hz, 120hz"
            return 1
            ;;
    esac
    
    # Set the preferences
    if [ -n "$layout_value" ]; then
        defaults write "$BUNDLE_ID" vtLayoutType -int "$layout_value"
    fi
    
    if [ -n "$refresh_value" ]; then
        defaults write "$BUNDLE_ID" N6PDisplayModeRaw -int "$refresh_value"
    fi
    
    # Set other optimal settings
    defaults write "$BUNDLE_ID" isExtendMode -int 1          # Extended mode (not mirror)
    defaults write "$BUNDLE_ID" reduceMotionBlur -int 1      # Reduce motion blur
    defaults write "$BUNDLE_ID" autoTurnOffMainDisplay -int 1 # Turn off main display
    
    echo -e "${GREEN}✓ Configuration updated${NC}"
}

# Function to start SpaceWalker
start_spacewalker() {
    echo -e "${BLUE}Starting SpaceWalker...${NC}"
    
    if is_running; then
        echo -e "${YELLOW}SpaceWalker is already running${NC}"
        # Force restart to apply new configuration
        echo "Restarting SpaceWalker to apply new configuration..."
        stop_spacewalker_force
        sleep 2
    fi
    
    # Launch the app
    open -a "SpaceWalker"
    
    # Wait for it to start
    local count=0
    while [ $count -lt 10 ]; do
        if is_running; then
            echo -e "${GREEN}✓ SpaceWalker started${NC}"
            break
        fi
        sleep 1
        ((count++))
    done
    
    if ! is_running; then
        echo -e "${RED}✗ Failed to start SpaceWalker${NC}"
        return 1
    fi
    
    # Wait for UI to initialize
    sleep 3
    
    # Try multiple methods to start XR session
    echo "Attempting to start XR session..."
    
    # Method 1: Click the "Launch SpaceWalker" button
    local button_clicked=false
    echo "Looking for Launch SpaceWalker button..."
    osascript << 'EOF' 2>/dev/null && button_clicked=true || true
tell application "SpaceWalker" to activate
delay 1
tell application "System Events"
    tell process "SpaceWalker"
        try
            if exists button "Launch SpaceWalker" of window 1 then
                click button "Launch SpaceWalker" of window 1
                log "Successfully clicked Launch SpaceWalker button"
            else
                -- Fallback: look for any button with Start/Launch/Begin
                set buttonList to name of every button of window 1
                repeat with buttonName in buttonList
                    if buttonName contains "Launch" or buttonName contains "Start" or buttonName contains "Begin" then
                        click button buttonName of window 1
                        log "Clicked button: " & buttonName
                        exit repeat
                    end if
                end repeat
            end if
        on error errMsg
            log "Button click error: " & errMsg
        end try
    end tell
end tell
EOF

    # Method 2: Try common keyboard shortcuts
    if [ "$button_clicked" = false ]; then
        echo "Trying keyboard shortcuts..."
        osascript << 'EOF' 2>/dev/null || true
tell application "SpaceWalker" to activate
delay 0.5
tell application "System Events"
    -- Try Return key
    key code 36
    delay 0.5
    -- Try Space key
    key code 49
    delay 0.5
    -- Try Enter key (numeric pad)
    key code 76
end tell
EOF
    fi
    
    # Method 3: Try clicking anywhere in the center of the window
    sleep 1
    osascript << 'EOF' 2>/dev/null || true
tell application "SpaceWalker" to activate
delay 0.5
tell application "System Events"
    tell process "SpaceWalker"
        try
            set windowBounds to bounds of window 1
            set centerX to (item 1 of windowBounds + item 3 of windowBounds) / 2
            set centerY to (item 2 of windowBounds + item 4 of windowBounds) / 2
            click at {centerX, centerY}
            log "Clicked center of window"
        end try
    end tell
end tell
EOF

    echo -e "${GREEN}✓ SpaceWalker session attempts completed${NC}"
}

# Function to force stop SpaceWalker
stop_spacewalker_force() {
    # Try graceful quit first
    osascript -e 'tell application "SpaceWalker" to quit' 2>/dev/null || true
    sleep 2
    
    # Try a more polite termination if still running
    if is_running; then
        # Send SIGTERM first (graceful shutdown)
        pkill -TERM -f "SpaceWalker" 2>/dev/null || true
        sleep 2
        
        # Only use SIGKILL as last resort
        if is_running; then
            pkill -KILL -f "SpaceWalker" 2>/dev/null || true
            sleep 1
        fi
    fi
}

# Function to stop SpaceWalker
stop_spacewalker() {
    echo -e "${BLUE}Stopping SpaceWalker...${NC}"
    
    if ! is_running; then
        echo -e "${YELLOW}SpaceWalker is not running${NC}"
        return 0
    fi
    
    # Try graceful quit first
    osascript -e 'tell application "SpaceWalker" to quit' 2>/dev/null || true
    
    # Wait longer for graceful shutdown
    local count=0
    while [ $count -lt 8 ]; do
        if ! is_running; then
            echo -e "${GREEN}✓ SpaceWalker stopped gracefully${NC}"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    # Try polite SIGTERM if AppleScript quit didn't work
    echo "Sending SIGTERM to SpaceWalker..."
    pkill -TERM -f "SpaceWalker" 2>/dev/null || true
    
    # Wait for SIGTERM to take effect
    count=0
    while [ $count -lt 5 ]; do
        if ! is_running; then
            echo -e "${GREEN}✓ SpaceWalker stopped${NC}"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    # Last resort: SIGKILL
    echo "Force killing SpaceWalker..."
    pkill -KILL -f "SpaceWalker" 2>/dev/null || true
    
    if ! is_running; then
        echo -e "${GREEN}✓ SpaceWalker stopped${NC}"
    else
        echo -e "${RED}✗ Failed to stop SpaceWalker${NC}"
        return 1
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}SpaceWalker Status${NC}"
    echo "=================="
    
    if is_running; then
        echo -e "Status: ${GREEN}Running${NC}"
        echo "PID: $(pgrep -f SpaceWalker)"
    else
        echo -e "Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo "Current Configuration:"
    echo "----------------------"
    
    # Read current settings
    layout=$(defaults read "$BUNDLE_ID" vtLayoutType 2>/dev/null || echo "unknown")
    refresh=$(defaults read "$BUNDLE_ID" N6PDisplayModeRaw 2>/dev/null || echo "unknown")
    extend=$(defaults read "$BUNDLE_ID" isExtendMode 2>/dev/null || echo "unknown")
    blur=$(defaults read "$BUNDLE_ID" reduceMotionBlur 2>/dev/null || echo "unknown")
    
    case "$layout" in
        0) layout_name="Single display" ;;
        1) layout_name="Side by side" ;;
        2) layout_name="Three wide" ;;
        *) layout_name="Unknown ($layout)" ;;
    esac
    
    case "$refresh" in
        20) refresh_name="60Hz" ;;
        52) refresh_name="120Hz" ;;
        *) refresh_name="Unknown ($refresh)" ;;
    esac
    
    echo "Layout: $layout_name"
    echo "Refresh: $refresh_name"
    echo "Extended mode: $extend"
    echo "Motion blur reduction: $blur"
}

# Function to reset settings
reset_settings() {
    echo -e "${BLUE}Resetting SpaceWalker settings...${NC}"
    
    if is_running; then
        echo "Stopping SpaceWalker first..."
        stop_spacewalker
    fi
    
    # Reset to defaults
    defaults write "$BUNDLE_ID" vtLayoutType -int 0
    defaults write "$BUNDLE_ID" N6PDisplayModeRaw -int 52
    defaults write "$BUNDLE_ID" isExtendMode -int 1
    defaults write "$BUNDLE_ID" reduceMotionBlur -int 1
    defaults write "$BUNDLE_ID" autoTurnOffMainDisplay -int 1
    
    echo -e "${GREEN}✓ Settings reset to defaults${NC}"
}

# Main command handling
case "${1:-}" in
    "start")
        set_config "$2" "$3"
        start_spacewalker
        ;;
    "stop")
        stop_spacewalker
        ;;
    "config")
        set_config "$2" "$3"
        ;;
    "status")
        show_status
        ;;
    "reset")
        reset_settings
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    "")
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac