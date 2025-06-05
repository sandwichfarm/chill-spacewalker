#!/usr/bin/swift

import Foundation

class SimpleSpaceWalkerDaemon {
    private let logger = Logger()
    private var isRunning = false
    private var lastKnownState = false
    private let lockFilePath = "/tmp/spacewalker_daemon_simple.lock"
    private var timer: Timer?
    
    init() {
        guard ensureSingleInstance() else {
            logger.log("Another instance is already running. Exiting.")
            exit(1)
        }
        
        setupSignalHandlers()
        logger.log("Simple SpaceWalker Daemon initialized")
    }
    
    func run() {
        isRunning = true
        logger.log("Starting Simple SpaceWalker Daemon")
        
        // Check initial state
        lastKnownState = checkVitureConnection()
        if lastKnownState {
            logger.log("VITURE glasses detected on startup - launching SpaceWalker")
            launchSpaceWalker()
        } else {
            logger.log("No VITURE glasses detected on startup")
        }
        
        // Start polling timer (every 2 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForStateChange()
        }
        
        // Keep the daemon running
        RunLoop.main.run()
    }
    
    private func checkForStateChange() {
        let currentState = checkVitureConnection()
        
        if currentState != lastKnownState {
            logger.log("State change detected: \(lastKnownState) -> \(currentState)")
            
            if currentState {
                // Connected
                logger.log("VITURE glasses connected")
                launchSpaceWalker()
            } else {
                // Disconnected
                logger.log("VITURE glasses disconnected")
                quitSpaceWalker()
            }
            
            lastKnownState = currentState
        }
    }
    
    private func checkVitureConnection() -> Bool {
        let usbConnected = isVitureUSBConnected()
        let displayConnected = isVitureDisplayListed()
        
        logger.log("USB: \(usbConnected), Display: \(displayConnected)")
        
        // Require BOTH to be true
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
            
            return output.contains("VITURE Pro XR Glasses")
        } catch {
            logger.log("Failed to run ioreg: \(error)")
            return false
        }
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
            
            return output.contains("VITURE") && output.contains("Online: Yes")
        } catch {
            logger.log("Failed to run system_profiler: \(error)")
            return false
        }
    }
    
    private func launchSpaceWalker() {
        logger.log("Launching SpaceWalker with 3-wide layout @ 120Hz")
        
        let scriptPath = "/Users/sandwich/Develop/better-spacewalker/spacewalker_control.sh"
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [scriptPath, "start", "threewide", "120hz"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            logger.log("SpaceWalker launch result: \(output)")
            
            if task.terminationStatus == 0 {
                logger.log("✓ SpaceWalker launched successfully")
            } else {
                logger.log("✗ SpaceWalker launch failed")
            }
        } catch {
            logger.log("Failed to launch SpaceWalker: \(error)")
        }
    }
    
    private func quitSpaceWalker() {
        logger.log("Stopping SpaceWalker")
        
        let scriptPath = "/Users/sandwich/Develop/better-spacewalker/spacewalker_control.sh"
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [scriptPath, "stop"]
        
        do {
            try task.run()
            task.waitUntilExit()
            logger.log("✓ SpaceWalker stopped")
        } catch {
            logger.log("Failed to stop SpaceWalker: \(error)")
        }
    }
    
    private func ensureSingleInstance() -> Bool {
        let lockFile = lockFilePath
        
        if FileManager.default.fileExists(atPath: lockFile) {
            if let pidString = try? String(contentsOfFile: lockFile, encoding: .utf8),
               let pid = Int(pidString) {
                
                let task = Process()
                task.launchPath = "/bin/ps"
                task.arguments = ["-p", String(pid)]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    if task.terminationStatus == 0 {
                        return false
                    }
                } catch {
                    // Error checking process - assume it's not running
                }
            }
            
            try? FileManager.default.removeItem(atPath: lockFile)
        }
        
        let pid = ProcessInfo.processInfo.processIdentifier
        try? String(pid).write(toFile: lockFile, atomically: true, encoding: .utf8)
        
        return true
    }
    
    private func setupSignalHandlers() {
        signal(SIGTERM) { _ in
            Logger().log("Received SIGTERM, shutting down...")
            try? FileManager.default.removeItem(atPath: "/tmp/spacewalker_daemon_simple.lock")
            exit(0)
        }
        
        signal(SIGINT) { _ in
            Logger().log("Received SIGINT, shutting down...")
            try? FileManager.default.removeItem(atPath: "/tmp/spacewalker_daemon_simple.lock")
            exit(0)
        }
    }
    
    deinit {
        timer?.invalidate()
        try? FileManager.default.removeItem(atPath: lockFilePath)
    }
}

class Logger {
    private let logFile = "/tmp/spacewalker_daemon_simple.log"
    
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
let daemon = SimpleSpaceWalkerDaemon()
daemon.run()