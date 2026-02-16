import Foundation

// Process Manager: Orchestrates the full launch chain
// The execution chain: iOS App → Box64 → Wine → Windows .exe
// This is how Winlator works on Android, adapted for iOS

class ProcessManager: ObservableObject {
    
    @Published var isRunning = false
    @Published var outputLog: [String] = []
    @Published var currentProcessName: String = ""
    @Published var fps: Int = 0
    
    private let box64Bridge = Box64Bridge()
    private let wineEngine = WineEngine()
    private let jitManager = JITManager()
    private let containerManager = ContainerManager()
    
    private var currentPID: Int?
    
    // MARK: - Launch Executable
    
    func launch(
        exePath: String,
        in container: WineContainer,
        arguments: [String] = [],
        onOutput: @escaping (String) -> Void
    ) {
        guard !isRunning else {
            onOutput("[Error] Another process is already running")
            return
        }
        
        isRunning = true
        currentProcessName = URL(fileURLWithPath: exePath).lastPathComponent
        outputLog.removeAll()
        
        let log: (String) -> Void = { [weak self] message in
            DispatchQueue.main.async {
                self?.outputLog.append(message)
                onOutput(message)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Check JIT
            log("[Winkor] Checking JIT status...")
            if self.jitManager.isJITEnabled {
                log("[Winkor] JIT is ENABLED - full speed dynarec")
            } else {
                log("[Winkor] WARNING: JIT is DISABLED - running in interpreter mode (slow)")
                log("[Winkor] Use SideJITServer to enable JIT for best performance")
            }
            
            // Step 2: Setup Box64 environment
            log("[Winkor] Configuring Box64 (x86-64 → ARM64 translator)...")
            let box64Env = self.box64Bridge.setupEnvironment(for: container)
            log("[Winkor] Box64 preset: \(container.box64Preset)")
            log("[Winkor] Box64 dynarec: \(box64Env["BOX64_DYNAREC"] ?? "1")")
            
            // Step 3: Setup Wine environment
            log("[Winkor] Configuring Wine (Windows API compatibility layer)...")
            let fullEnv = self.wineEngine.setupWineEnvironment(for: container, box64Env: box64Env)
            log("[Winkor] Wine prefix: \(fullEnv["WINEPREFIX"] ?? "unknown")")
            log("[Winkor] Windows version: \(container.windowsVersion)")
            
            // Step 4: Configure graphics pipeline
            log("[Winkor] Setting up graphics pipeline...")
            log("[Winkor] Graphics driver: \(container.graphicsDriver)")
            log("[Winkor] DX Wrapper: \(container.dxwrapperVersion)")
            self.logGraphicsPipeline(container: container, log: log)
            
            // Step 5: Prepare dynarec cache
            log("[Winkor] Preparing dynarec cache...")
            let cachePath = self.box64Bridge.prepareDynarecCache(for: container)
            log("[Winkor] Cache: \(cachePath.path)")
            
            // Step 6: Build command line
            log("[Winkor] Building launch command...")
            let cmdLine = self.box64Bridge.buildCommandLine(
                wineBinary: self.wineEngine.wineBinaryPath,
                exePath: exePath,
                args: arguments
            )
            log("[Winkor] Command: \(cmdLine.joined(separator: " "))")
            
            // Step 7: Launch
            log("[Winkor] ═══════════════════════════════════")
            log("[Winkor] Launching \(self.currentProcessName)...")
            log("[Winkor] ═══════════════════════════════════")
            
            // In production: use posix_spawn or Process to actually execute
            self.currentPID = self.wineEngine.launchExecutable(
                exePath: exePath,
                in: container,
                environment: fullEnv,
                arguments: arguments,
                onOutput: log,
                onExit: { [weak self] exitCode in
                    DispatchQueue.main.async {
                        self?.isRunning = false
                        log("[Winkor] Process exited with code: \(exitCode)")
                    }
                }
            )
            
            // Update container last used
            var updatedContainer = container
            updatedContainer.lastUsedAt = Date()
            var containers = self.containerManager.listContainers()
            if let idx = containers.firstIndex(where: { $0.id == container.id }) {
                containers[idx] = updatedContainer
                self.containerManager.saveContainers(containers)
            }
        }
    }
    
    func stop() {
        if let pid = currentPID {
            wineEngine.killProcess(pid: pid)
        }
        wineEngine.killAllProcesses()
        isRunning = false
        currentProcessName = ""
        currentPID = nil
    }
    
    // MARK: - Graphics Pipeline Logging
    
    private func logGraphicsPipeline(container: WineContainer, log: (String) -> Void) {
        // Show the full graphics translation chain
        // This is the magic of how Windows games render on iOS:
        //
        // Game uses DirectX 11 →
        //   DXVK translates to Vulkan →
        //     MoltenVK translates Vulkan to Metal →
        //       Metal renders on iOS GPU
        //
        // OR for OpenGL games:
        // Game uses OpenGL →
        //   VirGL translates to Metal →
        //     Metal renders on iOS GPU
        
        switch container.dxwrapperVersion {
        case "DXVK":
            log("[Graphics] Pipeline: DirectX 9/10/11 → DXVK → Vulkan → MoltenVK → Metal → GPU")
        case "DXVK + VKD3D":
            log("[Graphics] Pipeline: DirectX 9-12 → DXVK/VKD3D → Vulkan → MoltenVK → Metal → GPU")
        case "WineD3D":
            log("[Graphics] Pipeline: DirectX → WineD3D → OpenGL → VirGL → Metal → GPU")
        default:
            log("[Graphics] Pipeline: DirectX → Vulkan → Metal → GPU")
        }
        
        if container.graphicsDriver.contains("Turnip") {
            log("[Graphics] Vulkan driver: Turnip (Mesa Freedreno)")
        } else if container.graphicsDriver.contains("VirGL") {
            log("[Graphics] OpenGL driver: VirGL")
        }
        
        log("[Graphics] Resolution: \(container.screenResolution)")
    }
}
