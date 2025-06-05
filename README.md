# 🧊 Chill SpaceWalker

```
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                         🧊 CHILL SPACEWALKER 🥽                   ║
    ║                                                                   ║
    ║    ┌─────┐  ┌─────┐  ┌─────┐     🔌 Plug & Play Automation       ║
    ║    │ VR1 │  │ VR2 │  │ VR3 │     🚀 Zero Manual Interaction      ║
    ║    └─────┘  └─────┘  └─────┘     ⚡ 120Hz Triple Display          ║
    ║         ╲      │      ╱          🛡️  Background Daemon           ║
    ║          ╲     │     ╱           ✨ Just Chill & Code            ║
    ║           ╲    │    ╱                                             ║
    ║            ╲   │   ╱                                              ║
    ║             ╲  │  ╱               🥽 VITURE Pro XR                ║
    ║              ╲ │ ╱                🖥️  3-Wide @ 120Hz             ║
    ║               ╲│╱                 💻 macOS 15.3+                  ║
    ║                🕶️                 🎯 Auto Launch & Click          ║
    ╚═══════════════════════════════════════════════════════════════════╝
```

**The chillest way to automate your VITURE Pro XR glasses on macOS** 😎

[![macOS](https://img.shields.io/badge/macOS-15.3+-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![VITURE](https://img.shields.io/badge/VITURE-Pro%20XR-purple?style=flat-square&logo=vr)](https://www.viture.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Automation](https://img.shields.io/badge/Manual%20Clicking-0%25-brightgreen?style=flat-square)](README.md)

Just plug in your glasses and **chill** - everything else happens automatically!

This project provides a complete background automation system that seamlessly launches SpaceWalker when your VITURE Pro XR glasses are connected and automatically configures and starts your XR session. When you unplug the glasses, it gracefully shuts down SpaceWalker.

## ✨ Features

- **🔌 Plug & Play**: Automatically detects when VITURE glasses are connected/disconnected
- **🚀 Zero Interaction**: Launches SpaceWalker and starts XR session without any manual input
- **⚙️ Optimal Configuration**: Automatically sets 3-wide layout @ 120Hz for best experience
- **🛡️ Singleton Protection**: Only one daemon instance can run at a time
- **⚡ Race Condition Safe**: Debounced detection prevents rapid connect/disconnect issues
- **📝 Comprehensive Logging**: Full debug logs for troubleshooting
- **🔄 Auto-Restart**: Daemon automatically restarts if it crashes
- **👤 Invisible Operation**: Runs completely in background, no UI visible to user
- **🎯 CLI Control**: Complete command-line interface for manual control

## 🎯 What It Does

1. **Detects Connection**: Monitors for VITURE Pro XR glasses via USB and display detection
2. **Launches SpaceWalker**: Automatically opens the SpaceWalker application
3. **Configures Optimally**: Sets 3 displays side-by-side @ 120Hz refresh rate
4. **Starts XR Session**: Automatically clicks "Launch SpaceWalker" button
5. **Monitors Disconnection**: Detects when glasses are unplugged
6. **Graceful Shutdown**: Cleanly quits SpaceWalker when glasses are disconnected

## 📋 Requirements

- macOS 15.3 or later
- VITURE Pro XR glasses (Vendor ID: 0x35ca, Product ID: 0x101d)
- SpaceWalker app installed in `/Applications/SpaceWalker.app`
- Bash shell (pre-installed on macOS)
- Accessibility permissions for UI automation

## 🚀 Quick Installation

**⚠️ IMPORTANT: This system is designed to work automatically in the background. Once installed, it will be completely invisible to you and will only activate when you plug in your VITURE glasses.**

### 1. Download and Install

```bash
git clone https://github.com/sandwichfarm/chill-spacewalker.git
cd chill-spacewalker
./install.sh
```

### 2. Grant Permissions

The installer will guide you, but you need to:

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button and add **Terminal** (or whatever app you ran the installer from)
3. Enable the checkbox next to it

### 3. That's It!

The daemon is now running invisibly in the background. It will:
- ✅ Start automatically when you log in
- ✅ Launch SpaceWalker when you connect your glasses
- ✅ Configure 3-wide layout @ 120Hz automatically
- ✅ Click the "Launch SpaceWalker" button automatically
- ✅ Quit SpaceWalker when you disconnect the glasses

## 🔧 Manual CLI Control

The system includes a powerful CLI tool for manual control:

### Basic Commands

```bash
# Start with optimal settings (3-wide @ 120Hz)
./spacewalker_control.sh start threewide 120hz

# Start with different layouts
./spacewalker_control.sh start single 120hz
./spacewalker_control.sh start sidebyside 120hz

# Start with different refresh rates
./spacewalker_control.sh start threewide 60hz

# Stop SpaceWalker
./spacewalker_control.sh stop

# Check current status and configuration
./spacewalker_control.sh status

# Configure without starting
./spacewalker_control.sh config threewide 120hz

# Reset to default settings
./spacewalker_control.sh reset
```

### Layout Options

- **`single`** - Single large display
- **`sidebyside`** - Two displays side by side  
- **`threewide`** - Three displays side by side (recommended)

### Refresh Rate Options

- **`60hz`** - 60Hz refresh rate
- **`120hz`** - 120Hz refresh rate (recommended)

## 🔍 Advanced Usage

### Daemon Management

```bash
# Check daemon status
ps aux | grep spacewalker_daemon

# Stop the daemon
pkill -f spacewalker_daemon.sh

# Start the daemon manually
./spacewalker_daemon.sh &

# View real-time logs
tail -f /tmp/spacewalker_daemon.log
```

### Installation Management

```bash
# Check installation status
./install.sh status

# Uninstall completely
./install.sh uninstall

# Test the system
./test.sh
```

## 📁 File Structure

```
chill-spacewalker/
├── spacewalker_daemon.sh           # Main bash daemon (reliable)
├── spacewalker_control.sh          # CLI control interface
├── SpaceWalkerDaemon.swift         # Swift daemon (alternative)
├── com.spacewalker.daemon.plist    # LaunchAgent configuration
├── install.sh                      # Installation script
├── test.sh                         # Test suite
├── test_detection.swift            # Detection testing tool
├── debug_detection.sh              # Debug helper
├── grant_permissions.sh            # Permission helper
├── CLAUDE.md                       # Technical documentation
├── REVERSE_ENGINEERING.md          # Hardware analysis
└── README.md                       # This file
```

## 🔧 How It Works

### Detection Method

The daemon uses dual detection for maximum reliability:

1. **USB Detection**: Uses `ioreg` to detect VITURE Pro XR Glasses device
2. **Display Detection**: Uses `system_profiler` to verify display is online
3. **Combined Logic**: Requires BOTH USB and display to be present

### Configuration Management

SpaceWalker settings are stored in macOS preferences:
- **Layout**: `defaults write com.viture.spacewalker vtLayoutType -int 2` (3-wide)
- **Refresh**: `defaults write com.viture.spacewalker N6PDisplayModeRaw -int 52` (120Hz)
- **Extended Mode**: `defaults write com.viture.spacewalker isExtendMode -int 1`

### UI Automation

The system uses AppleScript to interact with SpaceWalker:
```applescript
tell application "SpaceWalker" to activate
tell application "System Events"
    tell process "SpaceWalker"
        click button "Launch SpaceWalker" of window 1
    end tell
end tell
```

### Graceful Shutdown

To prevent macOS crash dialogs, the system uses escalating shutdown:
1. **AppleScript quit** (most graceful)
2. **SIGTERM** (polite termination)  
3. **SIGKILL** (last resort only)

## 🐛 Troubleshooting

### Daemon Not Starting

1. **Check if it's running:**
   ```bash
   ps aux | grep spacewalker_daemon
   ```

2. **Check logs for errors:**
   ```bash
   tail -20 /tmp/spacewalker_daemon.log
   ```

3. **Manually start and check:**
   ```bash
   ./spacewalker_daemon.sh
   ```

### SpaceWalker Not Launching

1. **Verify SpaceWalker is installed:**
   ```bash
   ls -la "/Applications/SpaceWalker.app"
   ```

2. **Test CLI control manually:**
   ```bash
   ./spacewalker_control.sh start threewide 120hz
   ```

3. **Check configuration:**
   ```bash
   ./spacewalker_control.sh status
   ```

### Button Not Clicking

1. **Check Accessibility permissions:**
   - System Settings > Privacy & Security > Accessibility
   - Ensure Terminal (or your shell) is enabled

2. **Test AppleScript manually:**
   ```bash
   osascript -e 'tell application "System Events" to get name of every process'
   ```

3. **Look for UI errors in logs:**
   ```bash
   grep -i "button\|click\|launch" /tmp/spacewalker_daemon.log
   ```

### Detection Issues

1. **Verify glasses are properly connected:**
   ```bash
   ./test_detection.swift
   ```

2. **Check USB connection:**
   ```bash
   ioreg -r -d0 -c IOUSBDevice | grep -i viture
   ```

3. **Check display connection:**
   ```bash
   system_profiler SPDisplaysDataType | grep -i viture
   ```

### Common Issues & Solutions

| Problem | Solution |
|---------|----------|
| "Application quit unexpectedly" dialog | Fixed in latest version with graceful shutdown |
| Daemon starts but doesn't detect glasses | Check `./test_detection.swift` output |
| SpaceWalker launches but doesn't start session | Grant Accessibility permissions |
| Multiple daemon instances | Use `./install.sh uninstall` then reinstall |
| Daemon doesn't start on login | Check LaunchAgent in `~/Library/LaunchAgents/` |
| Wrong layout/refresh rate | Use `./spacewalker_control.sh config threewide 120hz` |

## 🔒 Security Notes

- **Accessibility permissions** are required for UI automation only
- **The daemon runs in user context** (not as root) for security
- **No network connections** are made by the daemon
- **All operations are local** to your machine
- **Logs contain no sensitive information**
- **Open source** - you can inspect all code

## 📊 Performance Impact

- **Memory usage**: ~2-5 MB (bash daemon)
- **CPU usage**: <0.1% (only during detection polling)
- **Battery impact**: Negligible
- **Startup time**: <1 second
- **Detection speed**: 3-second polling interval

## 🎛️ Configuration Reference

### SpaceWalker Preferences

```bash
# Layout types
vtLayoutType = 0  # Single display
vtLayoutType = 1  # Side by side  
vtLayoutType = 2  # Three wide (default)

# Refresh rates
N6PDisplayModeRaw = 20  # 60Hz
N6PDisplayModeRaw = 52  # 120Hz (default)

# Other settings
isExtendMode = 1          # Extended mode (not mirror)
reduceMotionBlur = 1      # Motion blur reduction
autoTurnOffMainDisplay = 1 # Turn off main display
```

### Device Identifiers

```bash
# VITURE Pro XR Glasses
Vendor ID: 0x35ca (13770)
Product ID: 0x101d (4125)
Manufacturer: "VITURE Pro"
Product Name: "VITURE Pro XR Glasses"
Display Name: "VITURE"
```

## 🚨 Important Notes

1. **This daemon runs automatically** - it's designed to be completely invisible
2. **Only works with VITURE Pro XR glasses** (specific vendor/product IDs)
3. **Requires SpaceWalker app** to be installed in `/Applications/`
4. **Accessibility permissions are mandatory** for button automation
5. **The daemon automatically starts on login** and runs continuously
6. **Graceful shutdown prevents crash dialogs**

## 🔄 Uninstallation

To completely remove the system:

```bash
./install.sh uninstall
```

This will:
- Stop the daemon
- Remove the LaunchAgent
- Delete binaries from `/usr/local/bin/`
- Clean up all log files
- Preserve SpaceWalker app and settings

## 🆘 Support

If you encounter any issues:

1. **Run the test suite**: `./test.sh`
2. **Check the logs**: `tail -20 /tmp/spacewalker_daemon.log`
3. **Test detection**: `./test_detection.swift`
4. **Verify permissions** in System Settings
5. **Try manual control**: `./spacewalker_control.sh start threewide 120hz`
6. **Reinstall if needed**: `./install.sh uninstall && ./install.sh`

## 🏗️ Development

### Testing New Features

```bash
# Test detection logic
./test_detection.swift

# Test daemon with debug output
./spacewalker_daemon.sh

# Test CLI control
./spacewalker_control.sh start threewide 120hz

# Run full test suite
./test.sh
```

### Contributing

The project is structured for easy modification:
- **Detection logic**: Edit `test_detection.swift` or `spacewalker_daemon.sh`
- **CLI control**: Edit `spacewalker_control.sh`
- **UI automation**: Edit the AppleScript sections in control script
- **Installation**: Edit `install.sh`

## 📄 License

This project is provided as-is for educational and personal use. Use at your own risk.

---

---

## 🎉 **Enjoy your seamless VITURE Pro XR experience!** 🥽✨

### *No more manual button clicking - just plug in and chill!* 🧊

<div align="center">

**Made with ❤️ for the VITURE community**

[⭐ Star this repo](https://github.com/sandwichfarm/chill-spacewalker) • [🐛 Report bugs](https://github.com/sandwichfarm/chill-spacewalker/issues) • [💡 Request features](https://github.com/sandwichfarm/chill-spacewalker/issues)

</div>