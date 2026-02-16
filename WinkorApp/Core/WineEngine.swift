import Foundation
import UIKit

class WineEngine {
    static let shared = WineEngine()
    
    private var wineContainer: String
    private var isInitialized = false
    
    init() {
        // Create container directory
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        self.wineContainer = "\(documentsPath)/wine_container"
        
        // Initialize container if needed
        if !FileManager.default.fileExists(atPath: wineContainer) {
            setupWineContainer()
        }
    }
    
    func setupWineContainer() {
        do {
            try FileManager.default.createDirectory(atPath: wineContainer, withIntermediateDirectories: true)
            
            // Create basic Windows directory structure
            let windowsDirs = [
                "drive_c/windows",
                "drive_c/Program Files", 
                "drive_c/Program Files (x86)",
                "drive_c/Users",
                "drive_c/Windows/System32"
            ]
            
            for dir in windowsDirs {
                let fullPath = "\(wineContainer)/\(dir)"
                try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            }
            
            // Create basic registry structure
            createBasicRegistry()
            
            isInitialized = true
            print("✅ Wine container initialized successfully")
            
        } catch {
            print("❌ Failed to setup Wine container: \(error)")
        }
    }
    
    private func createBasicRegistry() {
        let registryPath = "\(wineContainer)/system.reg"
        
        let basicRegistry = """
        WINE REGISTRY Version 2
        ;; All keys relative to \\Machine\\Software\\Microsoft\\Windows\\CurrentVersion
        
        [Software\\Microsoft\\Windows\\CurrentVersion]
        "ProgramFilesDir"="C:\\\\Program Files"
        "ProgramFilesDir (x86)"="C:\\\\Program Files (x86)"
        "CommonFilesDir"="C:\\\\Program Files\\\\Common Files"
        "CommonFilesDir (x86)"="C:\\\\Program Files (x86)\\\\Common Files"
        
        [Software\\Microsoft\\Windows NT\\CurrentVersion]
        "CurrentVersion"="6.1"
        "CurrentBuild"="7601"
        "ProductName"="Windows 7"
        "CSDVersion"="Service Pack 1"
        """
        
        try? basicRegistry.write(toFile: registryPath, atomically: true, encoding: .utf8)
    }
    
    func getContainerPath() -> String {
        return wineContainer
    }
    
    func getWindowsPath() -> String {
        return "\(wineContainer)/drive_c"
    }
    
    func isWineReady() -> Bool {
        return isInitialized && FileManager.default.fileExists(atPath: wineContainer)
    }
}
