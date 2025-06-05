#!/usr/bin/swift

import Foundation
import CoreGraphics
import IOKit
import IOKit.usb

class SpaceWalkerDaemon {
    private let logger = Logger()
    private var isRunning = false
    private var vitureConnected = false
    private var debounceTimer: Timer?
    private var spacewalkerProcess: Process?
    private let lockFilePath = "/tmp/spacewalker_daemon.lock"
    
    // VITURE Pro XR identifiers
    private let vitureVendorID: UInt16 = 0x35ca
    private let vitureProductID: UInt16 = 0x101d
    private let vitureDisplayName = "VITURE"
    
    init() {
        guard ensureSingleInstance() else {
            logger.log("Another instance is already running. Exiting.")
            exit(1)
        }
        
        setupSignalHandlers()
        logger.log("SpaceWalker Daemon initialized")
    }
    
    func run() {
        isRunning = true
        logger.log("Starting SpaceWalker Daemon")
        
        // Register display configuration callback
        let callback: CGDisplayReconfigurationCallBack = { (display, flags, userInfo) in
            guard let daemon = userInfo?.bindMemory(to: SpaceWalkerDaemon.self, capacity: 1).pointee else { return }
            daemon.handleDisplayChange(display: display, flags: flags)
        }
        
        let selfPtr = UnsafeMutablePointer<SpaceWalkerDaemon>.allocate(capacity: 1)
        selfPtr.initialize(to: self)
        
        let error = CGDisplayRegisterReconfigurationCallback(callback, selfPtr)
        if error != .success {
            logger.log("Failed to register display callback: \(error)")
            exit(1)
        }
        
        // Check initial state
        checkInitialVitureState()
        
        // Keep the daemon running
        RunLoop.main.run()
    }
    
    private func handleDisplayChange(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        logger.log("Display change detected. Flags: \(flags.rawValue)")
        
        if flags.contains(.addFlag) {
            logger.log("Display added: \(display)")
            checkForVitureDisplay()
        } else if flags.contains(.removeFlag) {
            logger.log("Display removed: \(display)")
            handleVitureDisconnect()
        }
    }
    
    private func checkInitialVitureState() {
        if isVitureDisplayConnected() {
            logger.log("VITURE display detected on startup")
            handleVitureConnect()
        }
    }
    
    private func checkForVitureDisplay() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.performVitureCheck()
        }
    }
    
    private func performVitureCheck() {
        if isVitureDisplayConnected() && !vitureConnected {
            handleVitureConnect()
        }
    }
    
    private func isVitureDisplayConnected() -> Bool {
        // Use multiple detection methods for reliability
        
        // Method 1: Check USB device via IOKit (most reliable for actual connection)
        let usbConnected = isVitureUSBConnected()
        
        // Method 2: Check display via system_profiler
        let displayConnected = isVitureDisplayListed()
        
        logger.log("USB connected: \(usbConnected), Display listed: \(displayConnected)")
        
        // Require BOTH USB and display to be present for true connection
        return usbConnected && displayConnected
    }
    
    private func isVitureUSBConnected() -> Bool {
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
                logger.log("Found VITURE USB device in IOKit")
                return true
            }
        } catch {
            logger.log("Failed to run ioreg: \(error)")
        }
        
        return false
    }
    
    private func isVitureDisplayListed() -> Bool {
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
                logger.log("Found VITURE display (online)")
                return true
            }
        } catch {
            logger.log("Failed to run system_profiler: \(error)")
        }
        
        return false
    }
    
    private func handleVitureConnect() {
        guard !vitureConnected else { return }
        
        vitureConnected = true
        logger.log("VITURE glasses connected - launching SpaceWalker")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.launchSpaceWalker()
        }
    }
    
    private func handleVitureDisconnect() {
        guard vitureConnected else { return }
        
        vitureConnected = false
        logger.log("VITURE glasses disconnected - quitting SpaceWalker")
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.quitSpaceWalker()
        }
    }
    
    private func launchSpaceWalker() {
        guard isSpaceWalkerInstalled() else {
            logger.log("SpaceWalker not found in /Applications")
            return
        }
        
        if isSpaceWalkerRunning() {
            logger.log("SpaceWalker already running - restarting with optimal config")
            // Stop and restart with proper configuration
            stopSpaceWalkerCLI()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startSpaceWalkerCLI()
            }
            return
        }
        
        logger.log("Starting SpaceWalker with CLI control...")
        startSpaceWalkerCLI()
    }
    
    private func startSpaceWalkerCLI() {
        // Try multiple locations for the control script
        let possiblePaths = [
            "/usr/local/bin/spacewalker_control.sh",
            "/Users/sandwich/Develop/better-spacewalker/spacewalker_control.sh",
            "./spacewalker_control.sh"
        ]
        
        var actualScriptPath = possiblePaths[0]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                actualScriptPath = path
                break
            }
        }
        
        logger.log("Using SpaceWalker control script at: \(actualScriptPath)")
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [actualScriptPath, "start", "threewide", "120hz"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            logger.log("SpaceWalker CLI output: \(output)")
            
            if task.terminationStatus == 0 {
                logger.log("SpaceWalker started successfully with 3-wide layout @ 120Hz")
            } else {
                logger.log("SpaceWalker CLI failed with status: \(task.terminationStatus)")
            }
        } catch {
            logger.log("Failed to execute SpaceWalker CLI: \(error)")
        }
    }
    
    private func stopSpaceWalkerCLI() {
        // Try multiple locations for the control script
        let possiblePaths = [
            "/usr/local/bin/spacewalker_control.sh",
            "/Users/sandwich/Develop/better-spacewalker/spacewalker_control.sh",
            "./spacewalker_control.sh"
        ]
        
        var actualScriptPath = possiblePaths[0]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                actualScriptPath = path
                break
            }
        }
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [actualScriptPath, "stop"]
        
        do {
            try task.run()
            task.waitUntilExit()
            logger.log("SpaceWalker stopped via CLI")
        } catch {
            logger.log("Failed to stop SpaceWalker via CLI: \(error)")
        }
    }
    
    private func clickStartButton() {
        logger.log("Attempting to start XR session")
        
        let script = """
        tell application "SpaceWalker" to activate
        delay 1
        tell application "System Events"
            tell process "SpaceWalker"
                try
                    -- Check if Start button exists
                    if exists button "Start" of window 1 then
                        click button "Start" of window 1
                        log "Successfully clicked Start button"
                    else
                        -- Check for other possible buttons or states
                        set buttonList to name of every button of window 1
                        if (count of buttonList) > 0 then
                            log "Available buttons: " & (buttonList as string)
                            -- Try to click the first button if it exists
                            click button 1 of window 1
                            log "Clicked first available button"
                        else
                            -- SpaceWalker might already be started
                            set windowTitle to name of window 1
                            if windowTitle contains "SpaceWalker" then
                                log "SpaceWalker session appears to be already active"
                            else
                                log "No Start button found, window title: " & windowTitle
                            end if
                        end if
                    end if
                on error errMsg
                    log "UI interaction error: " & errMsg
                    -- Check if it's a permission issue
                    if errMsg contains "assistive access" then
                        log "Accessibility permissions required"
                    else
                        log "SpaceWalker may already be running or in different state"
                    end if
                end try
            end tell
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            logger.log("AppleScript output: \(output)")
        } catch {
            logger.log("Failed to execute AppleScript: \(error)")
        }
    }
    
    private func quitSpaceWalker() {
        logger.log("Quitting SpaceWalker via CLI...")
        stopSpaceWalkerCLI()
        spacewalkerProcess = nil
    }
    
    private func isSpaceWalkerInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/Applications/SpaceWalker.app")
    }
    
    private func isSpaceWalkerRunning() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "SpaceWalker"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            return false
        }
    }
    
    private func ensureSingleInstance() -> Bool {
        let lockFile = lockFilePath
        
        // Check if lock file exists and process is still running
        if FileManager.default.fileExists(atPath: lockFile) {
            if let pidString = try? String(contentsOfFile: lockFile, encoding: .utf8),
               let pid = Int(pidString) {
                
                // Check if process is still running
                let task = Process()
                task.launchPath = "/bin/ps"
                task.arguments = ["-p", String(pid)]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    if task.terminationStatus == 0 {
                        // Process is still running
                        return false
                    }
                }
                catch {
                    // Error checking process - assume it's not running
                }
            }
            
            // Remove stale lock file
            try? FileManager.default.removeItem(atPath: lockFile)
        }
        
        // Create new lock file
        let pid = ProcessInfo.processInfo.processIdentifier
        try? String(pid).write(toFile: lockFile, atomically: true, encoding: .utf8)
        
        return true
    }
    
    private func setupSignalHandlers() {
        signal(SIGTERM) { _ in
            Logger().log("Received SIGTERM, shutting down...")
            try? FileManager.default.removeItem(atPath: "/tmp/spacewalker_daemon.lock")
            exit(0)
        }
        
        signal(SIGINT) { _ in
            Logger().log("Received SIGINT, shutting down...")
            try? FileManager.default.removeItem(atPath: "/tmp/spacewalker_daemon.lock")
            exit(0)
        }
    }
    
    deinit {
        try? FileManager.default.removeItem(atPath: lockFilePath)
    }
}

class Logger {
    private let logFile = "/tmp/spacewalker_daemon.log"
    
    func log(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        print(logMessage, terminator: "")
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let fileHandle = FileHandle(forWritingAtPath: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }
}

// Main execution
let daemon = SpaceWalkerDaemon()
daemon.run()