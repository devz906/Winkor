import Foundation

struct WineContainer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var windowsVersion: String
    var graphicsDriver: String
    var screenResolution: String
    var cpuCores: Int
    var ramMB: Int
    var dxwrapperVersion: String
    var box64Preset: String
    var customEnvVars: [String: String]
    var createdAt: Date
    var lastUsedAt: Date?
    var diskUsageMB: Int
    
    static func == (lhs: WineContainer, rhs: WineContainer) -> Bool {
        lhs.id == rhs.id
    }
    
    init(
        name: String,
        windowsVersion: String = "Windows 10",
        graphicsDriver: String = "Turnip (Vulkan)",
        screenResolution: String = "1280x720",
        cpuCores: Int = 4,
        ramMB: Int = 2048,
        dxwrapperVersion: String = "DXVK",
        box64Preset: String = "Default"
    ) {
        self.id = UUID()
        self.name = name
        self.windowsVersion = windowsVersion
        self.graphicsDriver = graphicsDriver
        self.screenResolution = screenResolution
        self.cpuCores = cpuCores
        self.ramMB = ramMB
        self.dxwrapperVersion = dxwrapperVersion
        self.box64Preset = box64Preset
        self.customEnvVars = [:]
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.diskUsageMB = 0
    }
}

class ContainerManager {
    
    private let fileManager = FileManager.default
    private let containersKey = "winkor_containers"
    
    var containersDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Containers")
    }
    
    init() {
        try? fileManager.createDirectory(at: containersDirectory, withIntermediateDirectories: true)
    }
    
    func listContainers() -> [WineContainer] {
        guard let data = UserDefaults.standard.data(forKey: containersKey),
              let containers = try? JSONDecoder().decode([WineContainer].self, from: data) else {
            return []
        }
        return containers
    }
    
    func saveContainers(_ containers: [WineContainer]) {
        if let data = try? JSONEncoder().encode(containers) {
            UserDefaults.standard.set(data, forKey: containersKey)
        }
    }
    
    func createContainer(_ container: WineContainer) -> Bool {
        let containerPath = containersDirectory.appendingPathComponent(container.id.uuidString)
        
        print("[ContainerManager] Creating container: \(container.name)")
        print("[ContainerManager] Path: \(containerPath.path)")
        print("[ContainerManager] Graphics: \(container.graphicsDriver)")
        print("[ContainerManager] DX Wrapper: \(container.dxwrapperVersion)")
        print("[ContainerManager] Windows: \(container.windowsVersion)")
        
        do {
            // Create Wine prefix directory structure
            print("[ContainerManager] Creating directory structure...")
            let paths = [
                "prefix",
                "prefix/drive_c",
                "prefix/drive_c/Windows",
                "prefix/drive_c/Windows/System32",
                "prefix/drive_c/Windows/SysWOW64",
                "prefix/drive_c/Windows/Fonts",
                "prefix/drive_c/Windows/Temp",
                "prefix/drive_c/Program Files",
                "prefix/drive_c/Program Files (x86)",
                "prefix/drive_c/ProgramData",
                "prefix/drive_c/users",
                "prefix/drive_c/users/winkor",
                "prefix/drive_c/users/winkor/Desktop",
                "prefix/drive_c/users/winkor/Documents",
                "prefix/drive_c/users/winkor/Downloads",
                "prefix/drive_c/users/winkor/AppData",
                "prefix/drive_c/users/winkor/AppData/Local",
                "prefix/drive_c/users/winkor/AppData/Local/Temp",
                "prefix/drive_c/users/winkor/AppData/Roaming",
                "config",
                "logs",
                "shortcuts"
            ]
            
            for path in paths {
                let fullPath = containerPath.appendingPathComponent(path)
                try fileManager.createDirectory(at: fullPath, withIntermediateDirectories: true)
                print("[ContainerManager] Created: \(path)")
            }
            
            // Write container configuration
            print("[ContainerManager] Writing configuration...")
            let configData = try JSONEncoder().encode(container)
            try configData.write(to: containerPath.appendingPathComponent("config/container.json"))
            
            // Write Wine registry stubs
            print("[ContainerManager] Writing registry files...")
            writeRegistryFiles(to: containerPath.appendingPathComponent("prefix"), container: container)
            
            // Write DLL stubs
            print("[ContainerManager] Writing DLL stubs...")
            writeDLLStubs(to: containerPath.appendingPathComponent("prefix/drive_c/Windows/System32"))
            
            // Save to container list
            var containers = listContainers()
            containers.append(container)
            saveContainers(containers)
            
            print("[ContainerManager] Created container: \(container.name) at \(containerPath.path)")
            return true
        } catch {
            print("[ContainerManager] Error creating container: \(error)")
            return false
        }
    }
    
    func deleteContainer(_ container: WineContainer) {
        let containerPath = containersDirectory.appendingPathComponent(container.id.uuidString)
        try? fileManager.removeItem(at: containerPath)
        
        var containers = listContainers()
        containers.removeAll { $0.id == container.id }
        saveContainers(containers)
    }
    
    func duplicateContainer(_ container: WineContainer) -> WineContainer {
        var newContainer = container
        newContainer = WineContainer(
            name: "\(container.name) (Copy)",
            windowsVersion: container.windowsVersion,
            graphicsDriver: container.graphicsDriver,
            screenResolution: container.screenResolution,
            cpuCores: container.cpuCores,
            ramMB: container.ramMB,
            dxwrapperVersion: container.dxwrapperVersion,
            box64Preset: container.box64Preset
        )
        _ = createContainer(newContainer)
        return newContainer
    }
    
    func containerPath(for container: WineContainer) -> URL {
        return containersDirectory.appendingPathComponent(container.id.uuidString)
    }
    
    func winePrefixPath(for container: WineContainer) -> URL {
        return containerPath(for: container).appendingPathComponent("prefix")
    }
    
    func driveCPath(for container: WineContainer) -> URL {
        return winePrefixPath(for: container).appendingPathComponent("drive_c")
    }
    
    func getContainerDiskUsage(_ container: WineContainer) -> Int {
        let path = containerPath(for: container)
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize: Int = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
            }
        }
        return totalSize / (1024 * 1024) // MB
    }
    
    // MARK: - Wine Registry Setup
    
    private func writeRegistryFiles(to prefixPath: URL, container: WineContainer) {
        let systemReg = """
        WINE REGISTRY Version 2
        ;; Generated by Winkor
        
        [System\\\\CurrentControlSet\\\\Control\\\\Windows]
        "CSDVersion"=dword:00000000
        
        [Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion]
        "ProductName"="\(container.windowsVersion)"
        "CSDVersion"=""
        "CurrentBuildNumber"="19045"
        "CurrentVersion"="10.0"
        
        [Software\\\\Wine\\\\Drivers]
        "Graphics"="\(container.graphicsDriver)"
        "Audio"="pulse"
        
        [Software\\\\Wine\\\\Direct3D]
        "renderer"="vulkan"
        "UseGLSL"="enabled"
        "VideoMemorySize"="2048"
        """
        
        let userReg = """
        WINE REGISTRY Version 2
        ;; User settings for Winkor
        
        [Software\\\\Wine\\\\Explorer\\\\Desktops]
        "Default"="\(container.screenResolution)"
        
        [Environment]
        "WINEARCH"="win64"
        "DXVK_HUD"="0"
        "MESA_GL_VERSION_OVERRIDE"="4.6"
        "BOX64_DYNAREC"="1"
        "BOX64_DYNAREC_BIGBLOCK"="1"
        """
        
        try? systemReg.write(to: prefixPath.appendingPathComponent("system.reg"), atomically: true, encoding: .utf8)
        try? userReg.write(to: prefixPath.appendingPathComponent("user.reg"), atomically: true, encoding: .utf8)
    }
    
    // MARK: - DLL Stubs
    
    private func writeDLLStubs(to system32Path: URL) {
        let coreDLLs = [
            "kernel32.dll", "user32.dll", "gdi32.dll", "advapi32.dll",
            "shell32.dll", "ole32.dll", "oleaut32.dll", "msvcrt.dll",
            "ntdll.dll", "ws2_32.dll", "winmm.dll", "comctl32.dll",
            "comdlg32.dll", "version.dll", "imm32.dll", "setupapi.dll",
            "crypt32.dll", "winspool.drv", "secur32.dll", "msvcp60.dll",
            "d3d9.dll", "d3d10.dll", "d3d10_1.dll", "d3d11.dll", "d3d12.dll",
            "dxgi.dll", "d3dcompiler_47.dll", "xinput1_3.dll", "xinput1_4.dll",
            "xinput9_1_0.dll", "xaudio2_7.dll", "x3daudio1_7.dll",
            "opengl32.dll", "vulkan-1.dll", "wined3d.dll",
            "vcruntime140.dll", "msvcp140.dll", "ucrtbase.dll",
            "api-ms-win-crt-runtime-l1-1-0.dll",
            "api-ms-win-crt-heap-l1-1-0.dll",
            "api-ms-win-crt-string-l1-1-0.dll",
            "api-ms-win-crt-stdio-l1-1-0.dll",
            "api-ms-win-crt-math-l1-1-0.dll"
        ]
        
        for dll in coreDLLs {
            let stub = "MZ\0\0Winkor DLL Stub: \(dll)"
            try? stub.write(to: system32Path.appendingPathComponent(dll), atomically: true, encoding: .utf8)
        }
    }
}
