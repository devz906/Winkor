import Foundation
import UIKit

class ContainerManager {
    static let shared = ContainerManager()
    
    private let wineEngine = WineEngine.shared
    private var currentContainer: String?
    
    func createContainer(name: String) -> Bool {
        let containerPath = "\(wineEngine.getContainerPath())/containers/\(name)"
        
        do {
            // Create container directory
            try FileManager.default.createDirectory(atPath: containerPath, withIntermediateDirectories: true)
            
            // Create container-specific directories
            let subdirs = [
                "drive_c",
                "dosdevices",
                "drive_c/windows",
                "drive_c/Program Files",
                "drive_c/Program Files (x86)",
                "drive_c/Users/Default",
                "drive_c/Windows/System32"
            ]
            
            for subdir in subdirs {
                let fullPath = "\(containerPath)/\(subdir)"
                try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            }
            
            // Create container registry
            createContainerRegistry(at: containerPath)
            
            // Create DOS devices symlinks
            createDosDevices(at: containerPath)
            
            currentContainer = name
            print("✅ Container '\(name)' created successfully")
            return true
            
        } catch {
            print("❌ Failed to create container: \(error)")
            return false
        }
    }
    
    private func createContainerRegistry(at path: String) {
        let userRegPath = "\(path)/user.reg"
        
        let userRegistry = """
        WINE REGISTRY Version 2
        ;; All keys relative to \\User\\.Default
        
        [Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders]
        "Desktop"="C:\\\\Users\\\\Default\\\\Desktop"
        "Personal"="C:\\\\Users\\\\Default\\\\Documents"
        "My Pictures"="C:\\\\Users\\\\Default\\\\Pictures"
        
        [Control Panel\\Desktop]
        "Wallpaper"=""
        "TileWallpaper"="0"
        """
        
        try? userRegistry.write(toFile: userRegPath, atomically: true, encoding: .utf8)
    }
    
    private func createDosDevices(at path: String) {
        let dosdevicesPath = "\(path)/dosdevices"
        
        // Create drive letter mappings
        let mappings = [
            "c:": "../drive_c",
            "z:": "/"
        ]
        
        for (drive, target) in mappings {
            let linkPath = "\(dosdevicesPath)/\(drive)"
            let targetPath = "\(dosdevicesPath)/\(target)"
            
            // Try to create symbolic link (may require special permissions)
            do {
                try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: targetPath)
            } catch {
                print("⚠️ Could not create symlink for \(drive): \(error)")
                // Fallback: create a file with the mapping info
                let mappingInfo = "target: \(target)"
                try? mappingInfo.write(toFile: linkPath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    func copyExeToContainer(_ exePath: String, containerName: String? = nil) -> String? {
        let container = containerName ?? currentContainer ?? "default"
        let containerPath = "\(wineEngine.getContainerPath())/containers/\(container)"
        let programFilesPath = "\(containerPath)/drive_c/Program Files"
        
        // Get exe filename
        let exeURL = URL(fileURLWithPath: exePath)
        let exeName = exeURL.lastPathComponent
        
        let destinationPath = "\(programFilesPath)/\(exeName)"
        
        do {
            // Copy exe to container
            try FileManager.default.copyItem(atPath: exePath, toPath: destinationPath)
            
            print("✅ Copied \(exeName) to container")
            return destinationPath
            
        } catch {
            print("❌ Failed to copy exe to container: \(error)")
            return nil
        }
    }
    
    func getContainerPath(_ name: String? = nil) -> String? {
        let container = name ?? currentContainer ?? "default"
        let containerPath = "\(wineEngine.getContainerPath())/containers/\(container)"
        
        if FileManager.default.fileExists(atPath: containerPath) {
            return containerPath
        }
        return nil
    }
    
    func listContainers() -> [String] {
        let containersPath = "\(wineEngine.getContainerPath())/containers"
        
        do {
            let containers = try FileManager.default.contentsOfDirectory(atPath: containersPath)
            return containers.filter { name in
                let containerPath = "\(containersPath)/\(name)"
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: containerPath, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            print("❌ Failed to list containers: \(error)")
            return []
        }
    }
    
    func setCurrentContainer(_ name: String) {
        if listContainers().contains(name) {
            currentContainer = name
            print("✅ Switched to container: \(name)")
        } else {
            print("❌ Container '\(name)' does not exist")
        }
    }
}
