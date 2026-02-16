import Foundation
import UIKit

class ProcessManager {
    static let shared = ProcessManager()
    
    private var runningProcesses: [String: Process] = [:]
    private let containerManager = ContainerManager.shared
    
    func executeExe(_ exePath: String, inContainer containerName: String? = nil, arguments: [String] = []) -> Bool {
        // Verify exe exists
        guard FileManager.default.fileExists(atPath: exePath) else {
            print("❌ EXE file not found: \(exePath)")
            return false
        }
        
        // Analyze PE file
        guard let peInfo = PELoader.shared.analyzePEFile(atPath: exePath) else {
            print("❌ Failed to analyze PE file")
            return false
        }
        
        // Check if executable
        guard peInfo.isExecutable else {
            print("❌ File is not executable")
            return false
        }
        
        // Check architecture compatibility
        guard PELoader.shared.canExecuteOniOS(peInfo) else {
            print("❌ EXE architecture not supported: \(peInfo.architecture)")
            return false
        }
        
        // Get container path
        guard let containerPath = containerManager.getContainerPath(containerName) else {
            print("❌ Container not found")
            return false
        }
        
        // For now, we'll simulate execution (real Wine integration comes later)
        return simulateExecution(exePath: exePath, peInfo: peInfo, containerPath: containerPath, arguments: arguments)
    }
    
    private func simulateExecution(exePath: String, peInfo: PELoader.PEInfo, containerPath: String, arguments: [String]) -> Bool {
        print("🚀 Starting execution simulation...")
        print("   EXE: \(URL(fileURLWithPath: exePath).lastPathComponent)")
        print("   Architecture: \(peInfo.architecture)")
        print("   Container: \(URL(fileURLWithPath: containerPath).lastPathComponent)")
        print("   Arguments: \(arguments.joined(separator: " "))")
        
        // Create a simulated process
        let process = Process()
        let exeName = URL(fileURLWithPath: exePath).lastPathComponent
        
        // For demonstration, we'll use a simple command that echoes the info
        // In real implementation, this would launch Wine with the exe
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = [
            "Simulating Windows execution:",
            "EXE: \(exeName)",
            "Architecture: \(peInfo.architecture)",
            "Entry Point: 0x\(String(peInfo.entryPoint, radix: 16))",
            "Image Size: \(peInfo.imageSize) bytes"
        ]
        
        // Set up environment variables for Wine
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = containerPath
        env["WINEARCH"] = peInfo.architecture == "x86-64" ? "win64" : "win32"
        env["DISPLAY"] = "" // No display for background execution
        
        process.environment = env
        
        // Set up pipes for output
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            runningProcesses[exeName] = process
            
            // Read output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("📋 Process output:")
                print(output)
            }
            
            process.waitUntilExit()
            
            let exitCode = process.terminationStatus
            if exitCode == 0 {
                print("✅ Process completed successfully")
            } else {
                print("⚠️ Process exited with code: \(exitCode)")
            }
            
            runningProcesses.removeValue(forKey: exeName)
            return exitCode == 0
            
        } catch {
            print("❌ Failed to start process: \(error)")
            return false
        }
    }
    
    func executeExeInContainer(_ exePath: String, containerName: String, arguments: [String] = []) -> Bool {
        // First copy exe to container
        guard let copiedPath = containerManager.copyExeToContainer(exePath, containerName: containerName) else {
            return false
        }
        
        // Then execute from container
        return executeExe(copiedPath, inContainer: containerName, arguments: arguments)
    }
    
    func getRunningProcesses() -> [String] {
        return Array(runningProcesses.keys)
    }
    
    func terminateProcess(_ exeName: String) -> Bool {
        guard let process = runningProcesses[exeName] else {
            print("❌ Process not found: \(exeName)")
            return false
        }
        
        process.terminate()
        runningProcesses.removeValue(forKey: exeName)
        print("🛑 Terminated process: \(exeName)")
        return true
    }
    
    func terminateAllProcesses() {
        for (name, process) in runningProcesses {
            process.terminate()
            print("🛑 Terminated process: \(name)")
        }
        runningProcesses.removeAll()
    }
}
