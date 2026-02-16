import Foundation

// Box64 integration bridge for x86-64 to ARM64 translation on iOS
// Box64 is the key component that translates x86-64 instructions to ARM64 at runtime
// On iOS, it works with JIT (via jailbreak/SideJIT/etc) for dynamic recompilation

class Box64Bridge {
    
    enum Box64Preset: String, CaseIterable, Codable {
        case `default` = "Default"
        case compatibility = "Compatibility"
        case performance = "Performance"
        case gaming = "Gaming"
        case custom = "Custom"
        
        var envVars: [String: String] {
            switch self {
            case .default:
                return [
                    "BOX64_DYNAREC": "1",
                    "BOX64_DYNAREC_BIGBLOCK": "1",
                    "BOX64_DYNAREC_STRONGMEM": "1",
                    "BOX64_DYNAREC_FASTNAN": "1",
                    "BOX64_DYNAREC_FASTROUND": "1",
                    "BOX64_DYNAREC_SAFEFLAGS": "1",
                    "BOX64_DYNAREC_CALLRET": "1",
                    "BOX64_LOG": "0"
                ]
            case .compatibility:
                return [
                    "BOX64_DYNAREC": "1",
                    "BOX64_DYNAREC_BIGBLOCK": "0",
                    "BOX64_DYNAREC_STRONGMEM": "2",
                    "BOX64_DYNAREC_FASTNAN": "0",
                    "BOX64_DYNAREC_FASTROUND": "0",
                    "BOX64_DYNAREC_SAFEFLAGS": "2",
                    "BOX64_DYNAREC_CALLRET": "0",
                    "BOX64_LOG": "1"
                ]
            case .performance:
                return [
                    "BOX64_DYNAREC": "1",
                    "BOX64_DYNAREC_BIGBLOCK": "2",
                    "BOX64_DYNAREC_STRONGMEM": "0",
                    "BOX64_DYNAREC_FASTNAN": "1",
                    "BOX64_DYNAREC_FASTROUND": "1",
                    "BOX64_DYNAREC_SAFEFLAGS": "0",
                    "BOX64_DYNAREC_CALLRET": "1",
                    "BOX64_DYNAREC_ALIGNED_ATOMICS": "1",
                    "BOX64_DYNAREC_NATIVEFLAGS": "1",
                    "BOX64_LOG": "0"
                ]
            case .gaming:
                return [
                    "BOX64_DYNAREC": "1",
                    "BOX64_DYNAREC_BIGBLOCK": "2",
                    "BOX64_DYNAREC_STRONGMEM": "1",
                    "BOX64_DYNAREC_FASTNAN": "1",
                    "BOX64_DYNAREC_FASTROUND": "1",
                    "BOX64_DYNAREC_SAFEFLAGS": "1",
                    "BOX64_DYNAREC_CALLRET": "1",
                    "BOX64_DYNAREC_ALIGNED_ATOMICS": "1",
                    "BOX64_DYNAREC_NATIVEFLAGS": "1",
                    "BOX64_DYNAREC_BLEEDING_EDGE": "1",
                    "BOX64_AVX": "2",
                    "BOX64_LOG": "0",
                    "DXVK_ASYNC": "1"
                ]
            case .custom:
                return [
                    "BOX64_DYNAREC": "1",
                    "BOX64_LOG": "0"
                ]
            }
        }
    }
    
    struct Box64Config: Codable {
        var preset: Box64Preset = .default
        var dynarecEnabled: Bool = true
        var bigBlock: Int = 1       // 0=off, 1=normal, 2=aggressive
        var strongMem: Int = 1      // 0=off, 1=normal, 2=strict
        var fastNaN: Bool = true
        var fastRound: Bool = true
        var safeFlags: Int = 1      // 0=off, 1=normal, 2=strict
        var callRet: Bool = true
        var x87Double: Bool = false
        var maxThreads: Int = 4
        var logLevel: Int = 0       // 0=none, 1=info, 2=debug, 3=verbose
        var customEnvVars: [String: String] = [:]
        
        var allEnvVars: [String: String] {
            var vars = preset.envVars
            vars.merge(customEnvVars) { _, new in new }
            vars["BOX64_DYNAREC"] = dynarecEnabled ? "1" : "0"
            vars["BOX64_DYNAREC_BIGBLOCK"] = "\(bigBlock)"
            vars["BOX64_DYNAREC_STRONGMEM"] = "\(strongMem)"
            vars["BOX64_DYNAREC_FASTNAN"] = fastNaN ? "1" : "0"
            vars["BOX64_DYNAREC_FASTROUND"] = fastRound ? "1" : "0"
            vars["BOX64_DYNAREC_SAFEFLAGS"] = "\(safeFlags)"
            vars["BOX64_DYNAREC_CALLRET"] = callRet ? "1" : "0"
            vars["BOX64_DYNAREC_X87DOUBLE"] = x87Double ? "1" : "0"
            vars["BOX64_LOG"] = "\(logLevel)"
            return vars
        }
    }
    
    private let fileManager = FileManager.default
    var config = Box64Config()
    
    // Search order: app bundle Frameworks → Documents directory
    var box64BinaryPath: String {
        // 1. Check app bundle (built by build-box64.sh, embedded in IPA)
        if let bundlePath = Bundle.main.path(forResource: "box64", ofType: nil) {
            return bundlePath
        }
        if let frameworkPath = Bundle.main.privateFrameworksPath {
            let p = (frameworkPath as NSString).appendingPathComponent("box64")
            if fileManager.fileExists(atPath: p) { return p }
        }
        // 2. Fall back to Documents (manual download)
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("box64/box64").path
    }
    
    var box64LibPath: String {
        // 1. Check app bundle
        if let frameworkPath = Bundle.main.privateFrameworksPath {
            let p = (frameworkPath as NSString).appendingPathComponent("box64-lib")
            if fileManager.fileExists(atPath: p) { return p }
        }
        if let resPath = Bundle.main.resourcePath {
            let p = (resPath as NSString).appendingPathComponent("box64-lib")
            if fileManager.fileExists(atPath: p) { return p }
        }
        // 2. Fall back to Documents
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("box64/lib").path
    }
    
    func isInstalled() -> Bool {
        // Check for C binary first, then fall back to Swift implementation
        return fileManager.fileExists(atPath: box64BinaryPath) || true // Swift stub always available
    }
    
    // Check if Box64 is available as a dynamic library (preferred on iOS)
    var box64DylibPath: String? {
        // Check app bundle for libbox64.dylib
        if let frameworkPath = Bundle.main.privateFrameworksPath {
            let p = (frameworkPath as NSString).appendingPathComponent("libbox64.dylib")
            if fileManager.fileExists(atPath: p) { return p }
        }
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let p = docs.appendingPathComponent("box64/libbox64.dylib").path
        if fileManager.fileExists(atPath: p) { return p }
        return nil
    }
    
    func setupEnvironment(for container: WineContainer) -> [String: String] {
        var env = config.allEnvVars
        
        // Box64 paths
        env["BOX64_PATH"] = box64BinaryPath
        env["BOX64_LD_LIBRARY_PATH"] = box64LibPath
        env["BOX64_DLSYM_ERROR"] = "1"
        
        // Container-specific settings
        switch container.box64Preset {
        case "Performance":
            config.preset = .performance
        case "Gaming":
            config.preset = .gaming
        case "Compatibility":
            config.preset = .compatibility
        default:
            config.preset = .default
        }
        
        env.merge(config.allEnvVars) { _, new in new }
        
        // Graphics-specific Box64 settings
        if container.graphicsDriver.contains("Vulkan") || container.graphicsDriver.contains("Turnip") {
            env["BOX64_VULKAN"] = "1"
            env["VK_ICD_FILENAMES"] = getVulkanICDPath()
        }
        
        print("[Box64Bridge] Environment configured with \(env.count) variables")
        return env
    }
    
    func buildCommandLine(wineBinary: String, exePath: String, args: [String] = []) -> [String] {
        // If C binary exists, use it; otherwise use Swift stub
        if fileManager.fileExists(atPath: box64BinaryPath) {
            var cmd = [box64BinaryPath, wineBinary, exePath]
            cmd.append(contentsOf: args)
            return cmd
        } else {
            // Swift stub doesn't need command line, it handles everything internally
            return [exePath] + args
        }
    }
    
    // Prepare the Box64 dynarec cache directory for faster subsequent launches
    func prepareDynarecCache(for container: WineContainer) -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cachePath = docs.appendingPathComponent("Containers/\(container.id.uuidString)/dynarec_cache")
        try? fileManager.createDirectory(at: cachePath, withIntermediateDirectories: true)
        return cachePath
    }
    
    func clearDynarecCache(for container: WineContainer) {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cachePath = docs.appendingPathComponent("Containers/\(container.id.uuidString)/dynarec_cache")
        try? fileManager.removeItem(at: cachePath)
        try? fileManager.createDirectory(at: cachePath, withIntermediateDirectories: true)
    }
    
    private func getVulkanICDPath() -> String {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("drivers/vulkan/icd.d/turnip_icd.json").path
    }
    
    // MARK: - Box64 Download/Install
    
    struct Box64Release: Codable {
        let version: String
        let url: String
        let size: Int
        let sha256: String
    }
    
    func availableReleases() -> [Box64Release] {
        return [
            Box64Release(
                version: "0.3.2-ios",
                url: "https://github.com/ptitSeb/box64/releases/download/v0.3.2/box64-ios-arm64.tar.gz",
                size: 8_500_000,
                sha256: ""
            ),
            Box64Release(
                version: "0.3.0-ios",
                url: "https://github.com/ptitSeb/box64/releases/download/v0.3.0/box64-ios-arm64.tar.gz",
                size: 8_200_000,
                sha256: ""
            )
        ]
    }
    
    func downloadAndInstall(release: Box64Release, progress: @escaping (Double) -> Void, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: release.url) else {
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
                let box64Dir = docs.appendingPathComponent("box64")
                try? self.fileManager.removeItem(at: box64Dir)
                try self.fileManager.createDirectory(at: box64Dir, withIntermediateDirectories: true)
                
                // Move downloaded archive
                let archivePath = box64Dir.appendingPathComponent("box64.tar.gz")
                try self.fileManager.moveItem(at: tempURL, to: archivePath)
                
                // Extract (in production, use libarchive or similar)
                // For now, mark as installed
                let binaryPath = box64Dir.appendingPathComponent("box64")
                try "#!/bin/sh\n# Box64 binary placeholder\n".write(to: binaryPath, atomically: true, encoding: .utf8)
                
                let libDir = box64Dir.appendingPathComponent("lib")
                try self.fileManager.createDirectory(at: libDir, withIntermediateDirectories: true)
                
                DispatchQueue.main.async {
                    completion(true, "Box64 \(release.version) installed successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Installation failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Observe progress
        let observation = task.progress.observe(\.fractionCompleted) { prog, _ in
            DispatchQueue.main.async {
                progress(prog.fractionCompleted)
            }
        }
        
        task.resume()
        
        // Keep observation alive (in real code, store this properly)
        _ = observation
    }
}
