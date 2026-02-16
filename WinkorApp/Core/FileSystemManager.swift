import Foundation

// FileSystem Manager: Maps Windows paths to iOS paths and manages the virtual file system
// Handles drive_c, registry, DLL overrides, and file redirection

class FileSystemManager {
    
    static let shared = FileSystemManager()
    
    private let fileManager = FileManager.default
    
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Path Translation
    
    func translateWindowsPath(_ windowsPath: String, container: WineContainer) -> URL {
        let containerManager = ContainerManager()
        let driveC = containerManager.driveCPath(for: container)
        
        var path = windowsPath
        
        // Normalize separators
        path = path.replacingOccurrences(of: "\\", with: "/")
        
        // Remove drive letter
        if path.count >= 2 && path[path.index(path.startIndex, offsetBy: 1)] == ":" {
            let driveLetter = path.prefix(1).uppercased()
            path = String(path.dropFirst(2))
            
            switch driveLetter {
            case "C":
                return driveC.appendingPathComponent(path)
            case "D":
                // D: drive maps to user's imported files
                return documentsDirectory.appendingPathComponent("imports/\(path)")
            case "Z":
                // Z: drive maps to iOS root (sandboxed)
                return documentsDirectory.appendingPathComponent("zroot/\(path)")
            default:
                return driveC.appendingPathComponent(path)
            }
        }
        
        // Relative path
        return driveC.appendingPathComponent(path)
    }
    
    // Translate special Windows folders
    func specialFolderPath(_ folder: WindowsSpecialFolder, container: WineContainer) -> URL {
        let containerManager = ContainerManager()
        let driveC = containerManager.driveCPath(for: container)
        let userDir = driveC.appendingPathComponent("users/winkor")
        
        switch folder {
        case .desktop:
            return userDir.appendingPathComponent("Desktop")
        case .documents:
            return userDir.appendingPathComponent("Documents")
        case .downloads:
            return userDir.appendingPathComponent("Downloads")
        case .appData:
            return userDir.appendingPathComponent("AppData/Roaming")
        case .localAppData:
            return userDir.appendingPathComponent("AppData/Local")
        case .temp:
            return driveC.appendingPathComponent("Windows/Temp")
        case .system32:
            return driveC.appendingPathComponent("Windows/System32")
        case .sysWOW64:
            return driveC.appendingPathComponent("Windows/SysWOW64")
        case .programFiles:
            return driveC.appendingPathComponent("Program Files")
        case .programFilesX86:
            return driveC.appendingPathComponent("Program Files (x86)")
        case .fonts:
            return driveC.appendingPathComponent("Windows/Fonts")
        case .startMenu:
            return userDir.appendingPathComponent("AppData/Roaming/Microsoft/Windows/Start Menu")
        }
    }
    
    enum WindowsSpecialFolder {
        case desktop, documents, downloads, appData, localAppData
        case temp, system32, sysWOW64, programFiles, programFilesX86
        case fonts, startMenu
    }
    
    // MARK: - File Operations
    
    func importFile(from sourceURL: URL, to container: WineContainer, windowsDestPath: String) throws {
        let destURL = translateWindowsPath(windowsDestPath, container: container)
        let destDir = destURL.deletingLastPathComponent()
        
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destURL)
        print("[FileSystem] Imported \(sourceURL.lastPathComponent) to \(windowsDestPath)")
    }
    
    func listDirectory(windowsPath: String, container: WineContainer) -> [(name: String, isDirectory: Bool, size: Int64)] {
        let url = translateWindowsPath(windowsPath, container: container)
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else {
            return []
        }
        
        return contents.compactMap { fileURL in
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDir = resourceValues?.isDirectory ?? false
            let size = Int64(resourceValues?.fileSize ?? 0)
            return (name: fileURL.lastPathComponent, isDirectory: isDir, size: size)
        }
    }
    
    func fileExists(windowsPath: String, container: WineContainer) -> Bool {
        let url = translateWindowsPath(windowsPath, container: container)
        return fileManager.fileExists(atPath: url.path)
    }
    
    func deleteFile(windowsPath: String, container: WineContainer) throws {
        let url = translateWindowsPath(windowsPath, container: container)
        try fileManager.removeItem(at: url)
    }
    
    // MARK: - Shortcut Management
    
    struct DesktopShortcut: Codable, Identifiable {
        let id: UUID
        var name: String
        var exePath: String
        var arguments: String
        var workingDirectory: String
        var iconData: Data?
        var containerID: UUID
    }
    
    func createShortcut(_ shortcut: DesktopShortcut, container: WineContainer) {
        let containerManager = ContainerManager()
        let shortcutsDir = containerManager.containerPath(for: container).appendingPathComponent("shortcuts")
        try? fileManager.createDirectory(at: shortcutsDir, withIntermediateDirectories: true)
        
        if let data = try? JSONEncoder().encode(shortcut) {
            try? data.write(to: shortcutsDir.appendingPathComponent("\(shortcut.id.uuidString).json"))
        }
    }
    
    func loadShortcuts(for container: WineContainer) -> [DesktopShortcut] {
        let containerManager = ContainerManager()
        let shortcutsDir = containerManager.containerPath(for: container).appendingPathComponent("shortcuts")
        
        guard let files = try? fileManager.contentsOfDirectory(at: shortcutsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let shortcut = try? JSONDecoder().decode(DesktopShortcut.self, from: data) else {
                return nil
            }
            return shortcut
        }
    }
    
    // MARK: - Disk Usage
    
    func getContainerSize(container: WineContainer) -> String {
        let containerManager = ContainerManager()
        let path = containerManager.containerPath(for: container)
        
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        
        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        if totalSize > 1_073_741_824 {
            return String(format: "%.1f GB", Double(totalSize) / 1_073_741_824)
        } else {
            return String(format: "%.0f MB", Double(totalSize) / 1_048_576)
        }
    }
    
    func getAvailableDiskSpace() -> String {
        do {
            let values = try documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return String(format: "%.1f GB", Double(capacity) / 1_073_741_824)
            }
        } catch {}
        return "Unknown"
    }
}
