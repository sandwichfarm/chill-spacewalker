#!/usr/bin/swift

import Foundation

// Test the improved detection logic
func isVitureUSBConnected() -> Bool {
    let task = Process()
    task.launchPath = "/usr/sbin/ioreg"
    task.arguments = ["-r", "-d0", "-c", "IOUSBDevice"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Check for VITURE device by product name
        if output.contains("VITURE Pro XR Glasses") {
            print("✓ Found VITURE USB device in IOKit")
            return true
        }
    } catch {
        print("Failed to run ioreg: \(error)")
    }
    
    print("✗ VITURE USB device NOT found in IOKit")
    return false
}

func isVitureDisplayListed() -> Bool {
    let task = Process()
    task.launchPath = "/usr/sbin/system_profiler"
    task.arguments = ["SPDisplaysDataType"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Check if output contains VITURE display AND it's marked as "Online: Yes"
        if output.contains("VITURE") && output.contains("Online: Yes") {
            print("✓ Found VITURE display (online)")
            return true
        }
    } catch {
        print("Failed to run system_profiler: \(error)")
    }
    
    print("✗ VITURE display NOT found or offline")
    return false
}

// Test detection
print("=== VITURE Detection Test ===")
let usbConnected = isVitureUSBConnected()
let displayConnected = isVitureDisplayListed()

print("\nResults:")
print("USB connected: \(usbConnected)")
print("Display connected: \(displayConnected)")
print("Overall connected: \(usbConnected && displayConnected)")

if usbConnected && displayConnected {
    print("\n🟢 VITURE glasses are CONNECTED")
} else {
    print("\n🔴 VITURE glasses are DISCONNECTED")
}