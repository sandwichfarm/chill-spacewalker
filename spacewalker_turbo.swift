#!/usr/bin/swift

import Foundation
import AppKit
import ApplicationServices

// SpaceWalker Turbo Launcher
// Ultra-fast, transparent automation

class TurboLauncher {
    private var observer: AXObserver?
    private var spacewalkerApp: AXUIElement?
    private var isMonitoring = false
    
    func launch() {
        print("🚀 Turbo mode activated")
        
        // Set configuration first
        setOptimalConfig()
        
        // Launch SpaceWalker hidden
        launchHidden()
        
        // Start monitoring for button
        startMonitoring()
        
        // Keep running
        RunLoop.main.run()
    }
    
    private func setOptimalConfig() {
        // Set preferences using NSUserDefaults
        let defaults = UserDefaults(suiteName: "com.viture.spacewalker")
        defaults?.set(2, forKey: "vtLayoutType")      // Three wide
        defaults?.set(52, forKey: "N6PDisplayModeRaw") // 120Hz
        defaults?.set(1, forKey: "isExtendMode")
        defaults?.set(1, forKey: "reduceMotionBlur")
        defaults?.set(1, forKey: "autoTurnOffMainDisplay")
        defaults?.synchronize()
    }
    
    private func launchHidden() {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = true
        
        let url = URL(fileURLWithPath: "/Applications/SpaceWalker.app")
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            if let app = app {
                print("✓ Launched (PID: \(app.processIdentifier))")
                self.setupAccessibility(pid: app.processIdentifier)
            }
        }
    }
    
    private func setupAccessibility(pid: pid_t) {
        spacewalkerApp = AXUIElementCreateApplication(pid)
        
        // Create observer
        var observer: AXObserver?
        AXObserverCreate(pid, axCallback, &observer)
        
        if let observer = observer {
            self.observer = observer
            
            // Watch for window creation
            AXObserverAddNotification(observer, spacewalkerApp!, kAXWindowCreatedNotification as CFString, nil)
            
            // Add to run loop
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            
            // Also check immediately
            checkForButton()
        }
    }
    
    private func checkForButton() {
        guard let app = spacewalkerApp else { return }
        
        var windows: AnyObject?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        
        if let windowArray = windows as? [AXUIElement], !windowArray.isEmpty {
            for window in windowArray {
                clickButtonInWindow(window)
            }
        }
        
        // Check again in 100ms if not found
        if !isMonitoring {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkForButton()
            }
        }
    }
    
    private func clickButtonInWindow(_ window: AXUIElement) {
        var children: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children)
        
        if let childArray = children as? [AXUIElement] {
            for child in childArray {
                if isLaunchButton(child) {
                    clickButton(child)
                    isMonitoring = true
                    
                    // Hide window after clicking
                    hideWindow(window)
                    
                    // Exit after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(0)
                    }
                    return
                }
                
                // Recursively check children
                clickButtonInWindow(child)
            }
        }
    }
    
    private func isLaunchButton(_ element: AXUIElement) -> Bool {
        var role: AnyObject?
        var title: AnyObject?
        
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        if let roleStr = role as? String, roleStr == "AXButton",
           let titleStr = title as? String, titleStr.contains("Launch") {
            return true
        }
        
        return false
    }
    
    private func clickButton(_ button: AXUIElement) {
        print("✓ Found Launch button - clicking")
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }
    
    private func hideWindow(_ window: AXUIElement) {
        // Minimize window
        var minimizeButton: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &minimizeButton)
        
        if let button = minimizeButton as? AXUIElement {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }
}

// Callback for notifications
func axCallback(observer: AXObserver, element: AXUIElement, notification: CFString, userData: UnsafeMutableRawPointer?) {
    // Handle window created notification
    let launcher = TurboLauncher()
    launcher.checkForButton()
}

// Check if Accessibility is enabled
func checkAccessibility() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
    return AXIsProcessTrustedWithOptions(options)
}

// Main execution
if !checkAccessibility() {
    print("❌ Accessibility permissions required")
    print("Grant permissions in System Settings > Privacy & Security > Accessibility")
    exit(1)
}

let launcher = TurboLauncher()
launcher.launch()