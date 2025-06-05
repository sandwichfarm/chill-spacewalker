# VITURE Pro XR Glasses - Reverse Engineering Documentation

## 🔍 Device Overview

The VITURE Pro XR glasses are a USB-C connected AR/VR headset that functions primarily as an external display with integrated sensors for head tracking and spatial computing.

## 📊 Hardware Identification

### USB Device Information
- **Vendor ID**: `0x35ca` (13770 decimal)
- **Product ID**: `0x101d` (4125 decimal)
- **Manufacturer**: `VITURE Pro`
- **Product Name**: `VITURE Pro XR Glasses`
- **Serial Number**: `2045305E4742` (example from test device)
- **USB Version**: `2.00`
- **Speed**: `Up to 12 Mb/s` (USB 2.0 Full Speed)
- **Power Requirements**: 300mA (up to 500mA available)
- **Location**: USB 3.1 Bus via AppleT8132USBXHCI

### Display Characteristics
- **Display Name**: `VITURE`
- **Resolution**: `1920 x 1080` (1080p FHD)
- **Refresh Rate**: `120Hz`
- **Connection Method**: DisplayPort Alt Mode over USB-C
- **Mirror Mode**: Disabled by default
- **UI Scaling**: 1:1 (no scaling applied)

## 🔌 Connection Architecture

### USB-C Implementation
The device uses **USB-C DisplayPort Alt Mode** which allows:
- **Video transmission** via DisplayPort protocol over USB-C
- **USB data** for sensors and controls (USB 2.0 speed)
- **Power delivery** (300mA @ 5V = 1.5W)

### Dual Interface Design
```
USB-C Connector
├── DisplayPort Alt Mode (Video)
│   ├── 1920x1080@120Hz signal
│   ├── EDID information
│   └── Display configuration
└── USB 2.0 Interface (Data)
    ├── HID devices (sensors)
    ├── Control interface
    └── Firmware communication
```

## 🖥️ Display Subsystem

### EDID Analysis
From system profiler output, the device presents itself as:
- **Product Name**: "VITURE"
- **Resolution**: 1920x1080
- **Preferred Refresh**: 120Hz
- **Color Depth**: Likely 8-bit RGB (standard)

### macOS Integration
```bash
# Display appears in system profiler
system_profiler SPDisplaysDataType | grep -A 20 VITURE

# Also creates additional virtual displays
"Dummy 16:9" displays (3200x1800@120Hz, scaled to 1600x900)
```

The "Dummy" displays suggest SpaceWalker creates virtual screens for the multi-monitor XR experience.

## 🔬 USB Interface Analysis

### Device Enumeration
```bash
# USB device details
system_profiler SPUSBDataType | grep -A 15 "VITURE Pro XR"
```

### IOKit Registry
```bash
# Device appears in IOKit registry
ioreg -r -d0 -c IOUSBDevice | grep -A 10 -B 5 "35ca"
ioreg -r -d0 -c AppleDisplay | grep -A 10 VITURE
```

### Communication Channels
The device likely implements multiple USB interfaces:
1. **HID Interface** - for sensors (gyroscope, accelerometer)
2. **Vendor Specific Interface** - for proprietary controls
3. **Mass Storage** - potentially for firmware updates

## 🎮 Sensor Capabilities

### Implied Sensors (based on XR functionality)
- **6DOF Head Tracking**: Gyroscope + Accelerometer
- **Magnetometer**: For absolute orientation
- **Proximity Sensor**: To detect when worn
- **Ambient Light Sensor**: For brightness adjustment

### Data Transmission
Sensor data likely transmitted via:
- **HID reports** for standard motion data
- **Vendor-specific USB transfers** for proprietary features
- **Low latency requirements** for head tracking (<20ms)

## 🔧 SpaceWalker Integration

### Software Interface
SpaceWalker acts as the bridge between macOS and the device:
- **Display Management**: Creates virtual monitors, handles mirroring
- **Sensor Processing**: Interprets head tracking data
- **Spatial Computing**: Renders 3D workspace
- **Power Management**: Likely controls display brightness, standby modes

### Observed Behavior
1. **Auto-detection**: macOS sees display connection immediately
2. **Driver Loading**: SpaceWalker provides the "driver" functionality
3. **Session Management**: Start/stop controls the XR experience
4. **Resource Management**: App manages GPU, display, and sensor resources

## 🛡️ Security Analysis

### Attack Surfaces
1. **USB Interface**: Standard USB security considerations
2. **Display Pipeline**: Video memory access
3. **Sensor Data**: Motion tracking privacy
4. **Firmware**: Potential update mechanism

### Observations
- **No root privileges required** for basic operation
- **Standard macOS permissions** (Screen Recording, Accessibility)
- **No network connectivity** from glasses themselves
- **User-space driver** (SpaceWalker app, not kernel extension)

## 🧪 Reverse Engineering Opportunities

### 1. USB Protocol Analysis
```bash
# Capture USB traffic (requires specialized tools)
# Tools: Wireshark with USBPcap, Bus Hound, or hardware analyzers

# Monitor IOKit calls
sudo dtruss -p $(pgrep SpaceWalker) | grep -i usb
sudo fs_usage -w -f filesystem -p $(pgrep SpaceWalker)
```

### 2. Sensor Data Extraction
```bash
# Look for HID devices
ls -la /dev/cu.* | grep -i usb
ioreg -r -c IOHIDDevice | grep -A 20 -B 5 -i viture

# Monitor HID reports
hidutil monitor --matching '{"VendorID":13770}'
```

### 3. Display Protocol Analysis
```bash
# Monitor display-related system calls
log stream --predicate 'process == "WindowServer"' | grep -i viture
sudo dtruss -p $(pgrep WindowServer) | grep -i display
```

### 4. Memory Analysis
```bash
# Analyze SpaceWalker memory usage
vmmap $(pgrep SpaceWalker) | grep -i usb
sample SpaceWalker 10 -file spacewalker_sample.txt
```

### 5. Network Traffic (if any)
```bash
# Monitor for any network activity
sudo lsof -i -p $(pgrep SpaceWalker)
netstat -an | grep $(pgrep SpaceWalker)
```

## 🔍 Firmware Analysis

### Potential Firmware Access
- **USB DFU Mode**: Device might support Device Firmware Upgrade
- **Vendor Commands**: Custom USB control transfers for firmware
- **EEPROM Access**: Configuration data storage

### Investigation Commands
```bash
# Look for DFU-capable devices
system_profiler SPUSBDataType | grep -i dfu
lsusb -d 35ca: -v  # If lsusb available via Homebrew

# Check for vendor-specific descriptors
ioreg -r -d2 -c IOUSBDevice | grep -A 50 -B 10 "35ca"
```

## 📡 Communication Protocol

### Hypothetical Protocol Stack
```
Application Layer: SpaceWalker App
    ├── 3D Rendering Commands
    ├── Sensor Data Processing
    └── Display Configuration
        │
Transport Layer: USB 2.0
    ├── HID Reports (sensors)
    ├── Vendor Commands (control)
    └── Bulk Transfers (firmware?)
        │
Physical Layer: USB-C + DisplayPort
    ├── DisplayPort Video Stream
    └── USB Differential Signaling
```

### Potential Command Structure
```c
// Hypothetical sensor data structure
typedef struct {
    uint16_t gyro_x, gyro_y, gyro_z;      // Angular velocity
    uint16_t accel_x, accel_y, accel_z;   // Linear acceleration
    uint16_t mag_x, mag_y, mag_z;         // Magnetic field
    uint8_t  buttons;                      // Touch/proximity sensors
    uint8_t  battery_level;               // If battery-powered
    uint32_t timestamp;                   // Synchronization
} __attribute__((packed)) sensor_report_t;
```

## 🔨 Reverse Engineering Tools

### macOS-Specific Tools
```bash
# System inspection
ioreg              # IOKit registry
system_profiler    # Hardware info
lsof              # Open files/devices
dtruss            # System call tracing
fs_usage          # File system usage
hidutil           # HID device monitoring

# Development tools
instruments       # Performance analysis
dtrace            # Dynamic tracing
lldb              # Debugging
```

### Third-Party Tools
```bash
# Install via Homebrew if needed
brew install libusb
brew install hidapi
brew install wireshark  # For USB capture

# Python libraries for USB
pip3 install pyusb
pip3 install hidapi
```

### Hardware Tools (Advanced)
- **USB Protocol Analyzer**: Beagle USB 480, Total Phase
- **Oscilloscope**: For signal analysis
- **Logic Analyzer**: For digital signal inspection
- **Multimeter**: Power consumption analysis

## 🚀 Research Directions

### 1. Sensor Fusion Analysis
- **IMU Calibration**: How does the device calibrate sensors?
- **Drift Correction**: What algorithms prevent orientation drift?
- **Coordinate Systems**: What reference frames are used?

### 2. Display Pipeline
- **Latency Optimization**: How is low-latency achieved?
- **Frame Synchronization**: How are frames synced with head motion?
- **Distortion Correction**: Lens distortion compensation methods?

### 3. Power Management
- **Sleep Modes**: Does device have power-saving states?
- **Thermal Management**: How is heat dissipation handled?
- **Battery Integration**: Any internal power storage?

### 4. Custom Protocol Development
- **Direct Sensor Access**: Bypass SpaceWalker for raw data
- **Custom Applications**: Build alternative software
- **Performance Optimization**: Lower-level optimizations

## 📋 Known Limitations & Mysteries

### Unknowns
1. **Exact sensor specifications** (accuracy, range, noise characteristics)
2. **Internal processing** (on-device vs host-based computation)
3. **Firmware update mechanism** (if any)
4. **Calibration procedures** (factory vs user calibration)
5. **Additional interfaces** (I2C, SPI internal busses?)
6. **Encryption/Authentication** (any secure communication?)

### Research Gaps
- **Complete USB descriptor analysis**
- **HID report descriptor mapping**
- **Vendor-specific command documentation**
- **Internal hardware architecture**
- **Firmware reverse engineering**

## 🎯 Next Steps for Reverse Engineering

### Phase 1: USB Protocol Documentation
1. **Capture all USB descriptors**
2. **Map HID report structures**
3. **Document vendor-specific commands**
4. **Analyze communication patterns**

### Phase 2: Sensor Data Analysis
1. **Raw sensor data extraction**
2. **Coordinate system mapping**
3. **Calibration procedure analysis**
4. **Performance characterization**

### Phase 3: Alternative Software Development
1. **Direct USB communication library**
2. **Cross-platform sensor driver**
3. **Custom XR applications**
4. **Performance optimization tools**

### Phase 4: Hardware Analysis
1. **Teardown documentation**
2. **PCB analysis and chip identification**
3. **Firmware extraction attempts**
4. **Hardware modification possibilities**

## ⚠️ Legal & Ethical Considerations

- **DMCA Compliance**: Respect copyright and licensing
- **Terms of Service**: Review VITURE's terms and conditions
- **Patent Awareness**: Be mindful of patented technologies
- **Responsible Disclosure**: Report security issues appropriately
- **Educational Purpose**: Focus on learning and interoperability

## 📚 References & Resources

### Technical Documentation
- [USB 2.0 Specification](https://www.usb.org/documents)
- [HID Usage Tables](https://usb.org/sites/default/files/hut1_2.pdf)
- [DisplayPort Standard](https://www.vesa.org/displayport/)
- [USB-C and DisplayPort Alt Mode](https://www.displayport.org/displayport-over-usb-c/)

### Tools & Libraries
- [PyUSB Documentation](https://pyusb.github.io/pyusb/)
- [libusb API Reference](https://libusb.sourceforge.io/api-1.0/)
- [IOKit Documentation](https://developer.apple.com/documentation/iokit)
- [Core Graphics Display Services](https://developer.apple.com/documentation/coregraphics/core_graphics_display_services)

---

**This document represents initial findings and should be expanded as more research is conducted. Contributions and additional findings are welcome!**