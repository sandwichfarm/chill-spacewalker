#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DAEMON_NAME="spacewalker-daemon"
PLIST_NAME="com.spacewalker.daemon.plist"
INSTALL_DIR="/usr/local/bin"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"

echo -e "${BLUE}SpaceWalker Daemon Installer${NC}"
echo "================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: This script should not be run as root${NC}"
   echo "Please run as a regular user with sudo privileges"
   exit 1
fi

# Check if SpaceWalker is installed
if [ ! -d "/Applications/SpaceWalker.app" ]; then
    echo -e "${YELLOW}Warning: SpaceWalker.app not found in /Applications${NC}"
    echo "Please install SpaceWalker before continuing"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to check if daemon is already running
check_running_daemon() {
    if pgrep -f "spacewalker-daemon" > /dev/null; then
        echo -e "${YELLOW}SpaceWalker daemon is currently running${NC}"
        echo "Stopping daemon..."
        launchctl unload "$LAUNCHAGENT_DIR/$PLIST_NAME" 2>/dev/null || true
        sleep 2
        pkill -f "spacewalker-daemon" 2>/dev/null || true
        sleep 1
    fi
}

# Function to compile Swift daemon
compile_daemon() {
    echo -e "${BLUE}Compiling SpaceWalker daemon...${NC}"
    
    if ! command -v swift &> /dev/null; then
        echo -e "${RED}Error: Swift compiler not found${NC}"
        echo "Please install Xcode or Command Line Tools"
        exit 1
    fi
    
    # Make the Swift file executable
    chmod +x SpaceWalkerDaemon.swift
    
    # Compile the daemon
    swiftc -o "$DAEMON_NAME" SpaceWalkerDaemon.swift
    
    if [ ! -f "$DAEMON_NAME" ]; then
        echo -e "${RED}Error: Failed to compile daemon${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Daemon compiled successfully${NC}"
}

# Function to install daemon
install_daemon() {
    echo -e "${BLUE}Installing daemon to $INSTALL_DIR...${NC}"
    
    # Create install directory if it doesn't exist
    sudo mkdir -p "$INSTALL_DIR"
    
    # Install the daemon
    sudo cp "$DAEMON_NAME" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$DAEMON_NAME"
    
    # Install the CLI control script
    if [ -f "spacewalker_control.sh" ]; then
        sudo cp "spacewalker_control.sh" "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/spacewalker_control.sh"
        echo -e "${GREEN}✓ CLI control script installed${NC}"
    fi
    
    echo -e "${GREEN}✓ Daemon installed to $INSTALL_DIR${NC}"
}

# Function to install LaunchAgent
install_launchagent() {
    echo -e "${BLUE}Installing LaunchAgent...${NC}"
    
    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$LAUNCHAGENT_DIR"
    
    # Install the plist
    cp "$PLIST_NAME" "$LAUNCHAGENT_DIR/"
    
    echo -e "${GREEN}✓ LaunchAgent installed${NC}"
}

# Function to check and request permissions
check_permissions() {
    echo -e "${BLUE}Checking system permissions...${NC}"
    
    # Check if Terminal/script has Accessibility permissions
    if ! sudo /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
        "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%Terminal%' AND auth_value=1;" 2>/dev/null | grep -q Terminal; then
        
        echo -e "${YELLOW}⚠ Accessibility permissions required${NC}"
        echo "To grant permissions:"
        echo "1. Open System Settings > Privacy & Security > Accessibility"
        echo "2. Add Terminal (or the app you're running this from)"
        echo "3. Enable the checkbox next to it"
        echo ""
        echo -e "${BLUE}This is required for the daemon to click the SpaceWalker Start button${NC}"
        echo ""
        read -p "Press Enter after granting permissions..."
    fi
    
    echo -e "${GREEN}✓ Permission check completed${NC}"
}

# Function to start the daemon
start_daemon() {
    echo -e "${BLUE}Starting SpaceWalker daemon...${NC}"
    
    # Load the LaunchAgent
    launchctl load "$LAUNCHAGENT_DIR/$PLIST_NAME"
    
    # Wait a moment for it to start
    sleep 2
    
    # Check if it's running
    if pgrep -f "spacewalker-daemon" > /dev/null; then
        echo -e "${GREEN}✓ SpaceWalker daemon started successfully${NC}"
        echo -e "${GREEN}✓ Daemon will automatically start on login${NC}"
    else
        echo -e "${RED}Error: Daemon failed to start${NC}"
        echo "Check logs:"
        echo "  tail -f /tmp/spacewalker_daemon.log"
        echo "  tail -f /tmp/spacewalker_daemon_stderr.log"
        exit 1
    fi
}

# Function to test the installation
test_installation() {
    echo -e "${BLUE}Testing installation...${NC}"
    
    # Check if daemon binary exists
    if [ ! -f "$INSTALL_DIR/$DAEMON_NAME" ]; then
        echo -e "${RED}✗ Daemon binary not found${NC}"
        return 1
    fi
    
    # Check if LaunchAgent is installed
    if [ ! -f "$LAUNCHAGENT_DIR/$PLIST_NAME" ]; then
        echo -e "${RED}✗ LaunchAgent not installed${NC}"
        return 1
    fi
    
    # Check if daemon is running
    if ! pgrep -f "spacewalker-daemon" > /dev/null; then
        echo -e "${RED}✗ Daemon not running${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All tests passed${NC}"
    return 0
}

# Function to show status
show_status() {
    echo ""
    echo -e "${BLUE}SpaceWalker Daemon Status:${NC}"
    echo "========================="
    
    if pgrep -f "spacewalker-daemon" > /dev/null; then
        echo -e "Status: ${GREEN}Running${NC}"
        echo "PID: $(pgrep -f 'spacewalker-daemon')"
    else
        echo -e "Status: ${RED}Stopped${NC}"
    fi
    
    echo "Log files:"
    echo "  Main: /tmp/spacewalker_daemon.log"
    echo "  Errors: /tmp/spacewalker_daemon_stderr.log"
    echo ""
    echo "To manage the daemon:"
    echo "  Stop:  launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
    echo "  Start: launchctl load ~/Library/LaunchAgents/$PLIST_NAME"
    echo "  View logs: tail -f /tmp/spacewalker_daemon.log"
}

# Function to uninstall
uninstall() {
    echo -e "${YELLOW}Uninstalling SpaceWalker daemon...${NC}"
    
    # Stop the daemon
    launchctl unload "$LAUNCHAGENT_DIR/$PLIST_NAME" 2>/dev/null || true
    sleep 1
    pkill -f "spacewalker-daemon" 2>/dev/null || true
    
    # Remove files
    sudo rm -f "$INSTALL_DIR/$DAEMON_NAME"
    rm -f "$LAUNCHAGENT_DIR/$PLIST_NAME"
    rm -f /tmp/spacewalker_daemon*
    
    echo -e "${GREEN}✓ SpaceWalker daemon uninstalled${NC}"
}

# Main installation process
main() {
    case "${1:-}" in
        "uninstall")
            uninstall
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "test")
            test_installation
            exit $?
            ;;
    esac
    
    echo -e "${BLUE}Starting installation...${NC}"
    
    # Stop any running daemon
    check_running_daemon
    
    # Compile the daemon
    compile_daemon
    
    # Install components
    install_daemon
    install_launchagent
    
    # Check permissions
    check_permissions
    
    # Start the daemon
    start_daemon
    
    # Test installation
    if test_installation; then
        echo ""
        echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
        echo ""
        echo -e "${BLUE}The SpaceWalker daemon is now running and will:${NC}"
        echo "• Automatically start when you log in"
        echo "• Launch SpaceWalker when VITURE glasses are connected"
        echo "• Click the Start button automatically"
        echo "• Quit SpaceWalker when glasses are disconnected"
        echo ""
        show_status
    else
        echo -e "${RED}Installation completed with errors${NC}"
        exit 1
    fi
}

# Handle command line arguments
if [ $# -eq 0 ]; then
    main
else
    main "$1"
fi