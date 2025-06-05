#!/bin/bash

# Script to grant accessibility permissions via CLI methods

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Accessibility Permission Granter${NC}"
echo "================================="

# Function to get the current app's bundle identifier
get_current_app() {
    # Try to determine what app is running this script
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        echo "com.googlecode.iterm2"
    elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "com.apple.Terminal"
    else
        echo "com.apple.Terminal"  # Default fallback
    fi
}

# Function to check if SIP is disabled
check_sip() {
    if csrutil status | grep -q "disabled"; then
        return 0
    else
        return 1
    fi
}

# Function to directly modify TCC database
direct_tcc_method() {
    local app_id="$1"
    echo -e "${BLUE}Attempting direct TCC database modification...${NC}"
    
    if ! check_sip; then
        echo -e "${RED}Error: System Integrity Protection (SIP) is enabled${NC}"
        echo "To use this method:"
        echo "1. Reboot and hold Cmd+R to enter Recovery Mode"
        echo "2. Open Terminal and run: csrutil disable"
        echo "3. Reboot normally and run this script again"
        echo "4. Re-enable SIP with: csrutil enable"
        return 1
    fi
    
    # Backup the database
    sudo cp "/Library/Application Support/com.apple.TCC/TCC.db" "/Library/Application Support/com.apple.TCC/TCC.db.backup"
    
    # Insert accessibility permission
    sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
      "INSERT OR REPLACE INTO access VALUES('kTCCServiceAccessibility','$app_id',0,2,2,1,NULL,NULL,0,'UNUSED',NULL,0,$(date +%s));"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Accessibility permission granted via TCC database${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to modify TCC database${NC}"
        return 1
    fi
}

# Function to use configuration profile method
profile_method() {
    local app_id="$1"
    echo -e "${BLUE}Creating configuration profile...${NC}"
    
    # Create temporary profile
    cat > /tmp/accessibility.mobileconfig << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.TCC.configuration-profile-policy</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>spacewalker.accessibility</string>
            <key>Services</key>
            <dict>
                <key>Accessibility</key>
                <array>
                    <dict>
                        <key>Allowed</key>
                        <true/>
                        <key>CodeRequirement</key>
                        <string>identifier "$app_id"</string>
                    </dict>
                </array>
            </dict>
        </dict>
    </array>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>spacewalker.accessibility.profile</string>
    <key>PayloadDisplayName</key>
    <string>SpaceWalker Accessibility</string>
</dict>
</plist>
EOF

    # Install the profile
    sudo profiles install -path /tmp/accessibility.mobileconfig
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Configuration profile installed${NC}"
        rm /tmp/accessibility.mobileconfig
        return 0
    else
        echo -e "${RED}✗ Failed to install configuration profile${NC}"
        rm /tmp/accessibility.mobileconfig
        return 1
    fi
}

# Function to provide manual instructions
manual_method() {
    echo -e "${YELLOW}Manual permission grant required:${NC}"
    echo ""
    echo "1. Open System Settings"
    echo "2. Go to Privacy & Security > Accessibility"
    echo "3. Click the '+' button"
    echo "4. Navigate to /Applications/Utilities/Terminal.app (or your terminal app)"
    echo "5. Click 'Open' and enable the checkbox"
    echo ""
    echo "Alternatively, you can:"
    echo "• Press Cmd+Space, type 'accessibility', press Enter"
    echo "• This opens the Accessibility preferences directly"
}

# Function to test permissions
test_permissions() {
    echo -e "${BLUE}Testing accessibility permissions...${NC}"
    
    # Try a simple AppleScript
    result=$(osascript -e 'tell application "System Events" to get name of every process' 2>&1)
    
    if [[ "$result" == *"not allowed assistive access"* ]]; then
        echo -e "${RED}✗ Accessibility permissions not granted${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Accessibility permissions working${NC}"
        return 0
    fi
}

# Main execution
main() {
    local app_id=$(get_current_app)
    echo "Detected terminal app: $app_id"
    echo ""
    
    # Test current permissions
    if test_permissions; then
        echo -e "${GREEN}Accessibility permissions already granted!${NC}"
        exit 0
    fi
    
    echo "Choose a method to grant accessibility permissions:"
    echo "1) Direct TCC database modification (requires SIP disabled)"
    echo "2) Configuration profile (may require restart)"
    echo "3) Manual instructions"
    echo "4) Exit"
    echo ""
    read -p "Select option (1-4): " choice
    
    case $choice in
        1)
            direct_tcc_method "$app_id"
            ;;
        2)
            profile_method "$app_id"
            ;;
        3)
            manual_method
            exit 0
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
    
    # Test permissions after attempting to grant
    echo ""
    echo "Testing permissions after grant attempt..."
    if test_permissions; then
        echo -e "${GREEN}✓ Success! Accessibility permissions granted${NC}"
        echo ""
        echo "The SpaceWalker daemon should now work fully automatically."
        echo "You can test by checking the logs:"
        echo "  tail -f /tmp/spacewalker_daemon.log"
    else
        echo -e "${YELLOW}⚠ Permissions may require a restart or manual grant${NC}"
        manual_method
    fi
}

main "$@"