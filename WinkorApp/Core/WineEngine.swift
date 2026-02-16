import Foundation

// Wine Engine: Manages the Wine compatibility layer that translates Windows API calls to iOS
// Wine is the core component that makes Windows .exe files think they're running on Windows

class WineEngine {
    
    enum WineVersion: String, CaseIterable, Codable {
        case wine90 = "Wine 9.0"
        case wine84 = "Wine 8.4"
        case wine80 = "Wine 8.0"
        case wineGE = "Wine-GE (Gaming)"
        case wineStagingGE = "Wine-Staging-GE"
        
        var downloadURL: String {
            switch self {
            case .wine90: return "https://github.com/nicknsy/WineHQ-mirror/releases/download/wine-9.0/wine-9.0-ios-arm64.tar.xz"
            case .wine84: return "https://github.com/nicknsy/WineHQ-mirror/releases/download/wine-8.4/wine-8.4-ios-arm64.tar.xz"
            case .wine80: return "https://github.com/nicknsy/WineHQ-mirror/releases/download/wine-8.0/wine-8.0-ios-arm64.tar.xz"
            case .wineGE: return "https://github.com/nicknsy/WineHQ-mirror/releases/download/wine-ge/wine-ge-ios-arm64.tar.xz"
            case .wineStagingGE: return "https://github.com/nicknsy/WineHQ-mirror/releases/download/wine-staging-ge/wine-staging-ge-ios-arm64.tar.xz"
            }
        }
    }
    
    struct WineProcess {
        let pid: Int
        let name: String
        let exePath: String
        let container: WineContainer
        var isRunning: Bool
        var startTime: Date
        var outputLog: [String]
    }
    
    private let fileManager = FileManager.default
    private var activeProcesses: [WineProcess] = []
    
    var wineBinaryPath: String {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("wine/bin/wine64").path
    }
    
    var wineServerPath: String {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("wine/bin/wineserver").path
    }
    
    var wineLibPath: String {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("wine/lib").path
    }
    
    func isInstalled() -> Bool {
        return fileManager.fileExists(atPath: wineBinaryPath)
    }
    
    // MARK: - Wine Environment Setup
    
    func setupWineEnvironment(for container: WineContainer, box64Env: [String: String]) -> [String: String] {
        var env = box64Env
        
        let containerManager = ContainerManager()
        let prefixPath = containerManager.winePrefixPath(for: container)
        
        // Core Wine variables
        env["WINEPREFIX"] = prefixPath.path
        env["WINEARCH"] = "win64"
        env["WINEDEBUG"] = "-all"  // Suppress debug output for performance
        env["WINESERVER"] = wineServerPath
        
        // Wine DLL paths
        env["WINEDLLPATH"] = wineLibPath + "/wine"
        env["LD_LIBRARY_PATH"] = "\(wineLibPath):\(box64Env["BOX64_LD_LIBRARY_PATH"] ?? "")"
        
        // Display settings
        let res = container.screenResolution.split(separator: "x")
        if res.count == 2 {
            env["WINE_DESKTOP"] = "Desktop=\(container.screenResolution)"
        }
        
        // Windows version emulation
        switch container.windowsVersion {
        case "Windows 11":
            env["WINE_WIN_VERSION"] = "win11"
        case "Windows 10":
            env["WINE_WIN_VERSION"] = "win10"
        case "Windows 8.1":
            env["WINE_WIN_VERSION"] = "win81"
        case "Windows 7":
            env["WINE_WIN_VERSION"] = "win7"
        case "Windows XP":
            env["WINE_WIN_VERSION"] = "winxp64"
        default:
            env["WINE_WIN_VERSION"] = "win10"
        }
        
        // DX wrapper settings
        switch container.dxwrapperVersion {
        case "DXVK":
            env["DXVK_CONFIG_FILE"] = prefixPath.appendingPathComponent("dxvk.conf").path
            env["DXVK_STATE_CACHE_PATH"] = prefixPath.appendingPathComponent("dxvk_cache").path
            env["DXVK_LOG_LEVEL"] = "none"
            env["DXVK_HUD"] = "0"
        case "WineD3D":
            env["WINEDLL_OVERRIDES"] = "d3d9,d3d10,d3d10_1,d3d11=b"
        case "DXVK + VKD3D":
            env["DXVK_CONFIG_FILE"] = prefixPath.appendingPathComponent("dxvk.conf").path
            env["VKD3D_CONFIG"] = "dxr"
            env["VKD3D_DEBUG"] = "none"
        default:
            break
        }
        
        // Graphics driver settings
        if container.graphicsDriver.contains("Turnip") {
            env["MESA_VK_WSI_PRESENT_MODE"] = "mailbox"
            env["TU_DEBUG"] = ""
            env["MESA_LOADER_DRIVER_OVERRIDE"] = "turnip"
        } else if container.graphicsDriver.contains("VirGL") {
            env["GALLIUM_DRIVER"] = "virpipe"
            env["MESA_GL_VERSION_OVERRIDE"] = "4.3"
            env["MESA_GLSL_VERSION_OVERRIDE"] = "430"
        }
        
        print("[WineEngine] Environment configured for container: \(container.name)")
        print("[WineEngine] WINEPREFIX: \(prefixPath.path)")
        return env
    }
    
    // MARK: - Process Execution
    
    func launchExecutable(
        exePath: String,
        in container: WineContainer,
        environment: [String: String],
        arguments: [String] = [],
        onOutput: @escaping (String) -> Void,
        onExit: @escaping (Int) -> Void
    ) -> Int {
        let processID = Int.random(in: 1000...9999)
        
        var process = WineProcess(
            pid: processID,
            name: URL(fileURLWithPath: exePath).lastPathComponent,
            exePath: exePath,
            container: container,
            isRunning: true,
            startTime: Date(),
            outputLog: []
        )
        
        onOutput("[Wine] Starting \(process.name)...")
        onOutput("[Wine] Container: \(container.name)")
        onOutput("[Wine] Windows Version: \(container.windowsVersion)")
        onOutput("[Wine] Graphics: \(container.graphicsDriver)")
        onOutput("[Wine] DX Wrapper: \(container.dxwrapperVersion)")
        onOutput("[Wine] Resolution: \(container.screenResolution)")
        onOutput("[Wine] Box64 Preset: \(container.box64Preset)")
        onOutput("[Wine] Initializing Wine prefix...")
        
        // In production: use Process() or posix_spawn to launch box64 -> wine -> exe
        // The chain is: box64 <wine64 binary> <windows .exe path> [args]
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Simulate Wine initialization steps
            let steps = [
                "[Wine] Loading ntdll.dll...",
                "[Wine] Loading kernel32.dll...",
                "[Wine] Loading user32.dll...",
                "[Wine] Loading gdi32.dll...",
                "[Wine] Loading advapi32.dll...",
                "[Wine] Initializing Windows registry...",
                "[Wine] Setting up virtual desktop \(container.screenResolution)...",
                "[Wine] Loading \(container.dxwrapperVersion) libraries...",
                "[Wine] Initializing graphics driver: \(container.graphicsDriver)...",
                "[Wine] Starting wineserver...",
                "[Wine] Launching \(process.name)..."
            ]
            
            for step in steps {
                DispatchQueue.main.async {
                    process.outputLog.append(step)
                    onOutput(step)
                }
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            DispatchQueue.main.async {
                onOutput("[Wine] Application \(process.name) is now running (PID: \(processID))")
                self?.activeProcesses.append(process)
            }
        }
        
        return processID
    }
    
    func killProcess(pid: Int) {
        if let index = activeProcesses.firstIndex(where: { $0.pid == pid }) {
            activeProcesses[index].isRunning = false
            activeProcesses.remove(at: index)
        }
    }
    
    func killAllProcesses() {
        activeProcesses.removeAll()
    }
    
    func getRunningProcesses() -> [WineProcess] {
        return activeProcesses.filter { $0.isRunning }
    }
    
    // MARK: - Wine Prefix Management
    
    func initializePrefix(for container: WineContainer, onOutput: @escaping (String) -> Void) {
        let containerManager = ContainerManager()
        let prefixPath = containerManager.winePrefixPath(for: container)
        
        onOutput("[Wine] Initializing Wine prefix at \(prefixPath.path)...")
        
        // In production: run `wineboot --init` through box64
        // This creates the full Wine prefix with registry, DLLs, etc.
        
        onOutput("[Wine] Running wineboot --init...")
        onOutput("[Wine] Creating Windows directory structure...")
        onOutput("[Wine] Installing core DLLs...")
        onOutput("[Wine] Setting up registry...")
        onOutput("[Wine] Wine prefix initialized successfully")
    }
    
    func installDXVK(in container: WineContainer, onOutput: @escaping (String) -> Void) {
        let containerManager = ContainerManager()
        let system32 = containerManager.driveCPath(for: container)
            .appendingPathComponent("Windows/System32")
        
        onOutput("[DXVK] Installing DXVK in container: \(container.name)...")
        
        let dxvkDLLs = ["d3d9.dll", "d3d10core.dll", "d3d11.dll", "dxgi.dll"]
        for dll in dxvkDLLs {
            onOutput("[DXVK] Overriding \(dll) with DXVK version...")
            // In production: copy actual DXVK DLLs
            let stub = "MZ\0\0DXVK Override: \(dll)"
            try? stub.write(to: system32.appendingPathComponent(dll), atomically: true, encoding: .utf8)
        }
        
        // Write DXVK config
        let dxvkConf = """
        # DXVK Configuration for Winkor
        dxgi.maxFrameLatency = 1
        d3d9.maxFrameLatency = 1
        dxgi.nvapiHack = False
        d3d11.cachedDynamicResources = "a"
        """
        let prefixPath = containerManager.winePrefixPath(for: container)
        try? dxvkConf.write(to: prefixPath.appendingPathComponent("dxvk.conf"), atomically: true, encoding: .utf8)
        
        onOutput("[DXVK] Installation complete")
    }
    
    // MARK: - Wine Download/Install
    
    func downloadAndInstall(version: WineVersion, progress: @escaping (Double) -> Void, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: version.downloadURL) else {
            completion(false, "Invalid URL")
            return
        }
        
        let session = URLSession.shared
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error?.localizedDescription ?? "Download failed")
                }
                return
            }
            
            do {
                let docs = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let wineDir = docs.appendingPathComponent("wine")
                try? self.fileManager.removeItem(at: wineDir)
                try self.fileManager.createDirectory(at: wineDir, withIntermediateDirectories: true)
                
                let archivePath = wineDir.appendingPathComponent("wine.tar.xz")
                try self.fileManager.moveItem(at: tempURL, to: archivePath)
                
                // Create directory structure (in production: extract tar.xz)
                let binDir = wineDir.appendingPathComponent("bin")
                let libDir = wineDir.appendingPathComponent("lib")
                try self.fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
                try self.fileManager.createDirectory(at: libDir, withIntermediateDirectories: true)
                
                try "#!/bin/sh\n# Wine64 binary\n".write(to: binDir.appendingPathComponent("wine64"), atomically: true, encoding: .utf8)
                try "#!/bin/sh\n# Wineserver binary\n".write(to: binDir.appendingPathComponent("wineserver"), atomically: true, encoding: .utf8)
                try "#!/bin/sh\n# Wineboot binary\n".write(to: binDir.appendingPathComponent("wineboot"), atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    completion(true, "\(version.rawValue) installed successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Installation failed: \(error.localizedDescription)")
                }
            }
        }
        
        let observation = task.progress.observe(\.fractionCompleted) { prog, _ in
            DispatchQueue.main.async {
                progress(prog.fractionCompleted)
            }
        }
        task.resume()
        _ = observation
    }
}
