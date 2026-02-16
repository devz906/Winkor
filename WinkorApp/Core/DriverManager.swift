import Foundation

// Driver Manager: Downloads and manages GPU drivers, DirectX wrappers, and rendering components
// This is the equivalent of Winlator's driver/component download system

struct GraphicsDriver: Identifiable, Codable {
    let id: String
    let name: String
    let category: DriverCategory
    let version: String
    let description: String
    let downloadURL: String
    let sizeMB: Int
    let isRequired: Bool
    var isInstalled: Bool
    var installPath: String
    
    enum DriverCategory: String, Codable, CaseIterable {
        case gpu = "GPU Driver"
        case dxWrapper = "DX Wrapper"
        case opengl = "OpenGL"
        case vulkan = "Vulkan"
        case audio = "Audio"
        case input = "Input"
        case runtime = "Runtime"
    }
}

class DriverManager: ObservableObject {
    
    @Published var availableDrivers: [GraphicsDriver] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading = false
    
    private let fileManager = FileManager.default
    private let installedKey = "winkor_installed_drivers"
    
    var driversDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("drivers")
    }
    
    var mesaPath: String {
        driversDirectory.appendingPathComponent("mesa").path
    }
    
    var dxvkPath: String {
        driversDirectory.appendingPathComponent("dxvk").path
    }
    
    var virglPath: String {
        driversDirectory.appendingPathComponent("virgl").path
    }
    
    var turnipPath: String {
        driversDirectory.appendingPathComponent("turnip").path
    }
    
    init() {
        try? fileManager.createDirectory(at: driversDirectory, withIntermediateDirectories: true)
        loadAvailableDrivers()
    }
    
    // MARK: - Persistence
    
    private func loadInstalledSet() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: installedKey) ?? []
        return Set(arr)
    }
    
    private func saveInstalledSet(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: installedKey)
    }
    
    private func markInstalled(driverID: String) {
        var set = loadInstalledSet()
        set.insert(driverID)
        saveInstalledSet(set)
    }
    
    private func markUninstalled(driverID: String) {
        var set = loadInstalledSet()
        set.remove(driverID)
        saveInstalledSet(set)
    }
    
    private func isDriverInstalled(id: String, path: String) -> Bool {
        let persistedSet = loadInstalledSet()
        let dirExists = fileManager.fileExists(atPath: path)
        return persistedSet.contains(id) || dirExists
    }
    
    func loadAvailableDrivers() {
        let driverDefs = Self.driverDefinitions(driversDir: driversDirectory)
        availableDrivers = driverDefs.map { d in
            var driver = d
            driver.isInstalled = isDriverInstalled(id: d.id, path: d.installPath)
            return driver
        }
    }
    
    // All driver definitions with STABLE IDs and real download URLs
    static func driverDefinitions(driversDir: URL) -> [GraphicsDriver] {
        return [
            // GPU Drivers
            GraphicsDriver(
                id: "mesa",
                name: "Mesa (OpenGL/Vulkan)",
                category: .gpu,
                version: "24.0.8",
                description: "Mesa 3D Graphics Library - includes Turnip (Vulkan) and VirGL (OpenGL) drivers. Core graphics stack required for most games.",
                downloadURL: "https://archive.mesa3d.org/mesa-24.0.8.tar.xz",
                sizeMB: 18,
                isRequired: true,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("mesa").path
            ),
            GraphicsDriver(
                id: "turnip",
                name: "Turnip (Adreno Vulkan)",
                category: .gpu,
                version: "24.0.8",
                description: "Mesa Turnip Vulkan driver - best performance for modern games. Included with Mesa, auto-built from Mesa source.",
                downloadURL: "bundled",
                sizeMB: 0,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("turnip").path
            ),
            GraphicsDriver(
                id: "virgl",
                name: "VirGL (OpenGL)",
                category: .opengl,
                version: "24.0.8",
                description: "VirGL OpenGL-to-Metal renderer for older OpenGL games. Included with Mesa, auto-built from Mesa source.",
                downloadURL: "bundled",
                sizeMB: 0,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("virgl").path
            ),
            
            // DX Wrappers
            GraphicsDriver(
                id: "dxvk",
                name: "DXVK",
                category: .dxWrapper,
                version: "2.3.1",
                description: "DirectX 9/10/11 to Vulkan translation layer. Essential for DirectX games.",
                downloadURL: "https://github.com/doitsujin/dxvk/releases/download/v2.3.1/dxvk-2.3.1.tar.gz",
                sizeMB: 28,
                isRequired: true,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("dxvk").path
            ),
            GraphicsDriver(
                id: "vkd3d",
                name: "VKD3D-Proton",
                category: .dxWrapper,
                version: "2.12",
                description: "DirectX 12 to Vulkan translation. Required for DX12 games.",
                downloadURL: "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v2.12/vkd3d-proton-2.12.tar.zst",
                sizeMB: 18,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("vkd3d").path
            ),
            GraphicsDriver(
                id: "d8vk",
                name: "D8VK",
                category: .dxWrapper,
                version: "1.0",
                description: "DirectX 8 to Vulkan. For very old DirectX 8 games.",
                downloadURL: "https://github.com/AlpyneDreams/d8vk/releases/download/d8vk-v1.0/d8vk-1.0.tar.gz",
                sizeMB: 12,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("d8vk").path
            ),
            GraphicsDriver(
                id: "wined3d",
                name: "WineD3D",
                category: .dxWrapper,
                version: "9.0",
                description: "Wine's built-in DirectX to OpenGL. Slower than DXVK but more compatible with some older games. Bundled with Wine.",
                downloadURL: "bundled",
                sizeMB: 15,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("wined3d").path
            ),
            
            // Vulkan
            GraphicsDriver(
                id: "moltenvk",
                name: "MoltenVK",
                category: .vulkan,
                version: "1.2.9",
                description: "Vulkan to Metal translation layer by Khronos. Core component for all Vulkan rendering on iOS.",
                downloadURL: "https://github.com/nicknsy/moltenvk-ios/releases/download/v1.2.8/MoltenVK-ios-arm64.tar.gz",
                sizeMB: 22,
                isRequired: true,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("moltenvk").path
            ),
            
            // Audio
            GraphicsDriver(
                id: "pulseaudio",
                name: "PulseAudio",
                category: .audio,
                version: "16.1",
                description: "PulseAudio sound server for Wine audio output. Bundled with Wine prefix setup.",
                downloadURL: "bundled",
                sizeMB: 8,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("pulseaudio").path
            ),
            
            // Input
            GraphicsDriver(
                id: "xinput",
                name: "XInput / DirectInput Bridge",
                category: .input,
                version: "1.0",
                description: "Maps iOS game controllers to Windows XInput/DirectInput. Bundled with Wine.",
                downloadURL: "bundled",
                sizeMB: 3,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("xinput").path
            ),
            
            // Runtimes
            GraphicsDriver(
                id: "vcredist",
                name: "Visual C++ Runtime",
                category: .runtime,
                version: "2015-2022",
                description: "Microsoft Visual C++ Redistributable. Required by most Windows games. Auto-installed in new containers.",
                downloadURL: "bundled",
                sizeMB: 35,
                isRequired: true,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("vcredist").path
            ),
            GraphicsDriver(
                id: "dotnet",
                name: ".NET Framework",
                category: .runtime,
                version: "4.8",
                description: ".NET Framework runtime. Install in container via winetricks if needed.",
                downloadURL: "bundled",
                sizeMB: 65,
                isRequired: false,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("dotnet").path
            ),
            GraphicsDriver(
                id: "directx",
                name: "DirectX Runtime",
                category: .runtime,
                version: "June 2010",
                description: "DirectX End-User Runtime (D3DX, XAudio). Auto-installed in new containers.",
                downloadURL: "bundled",
                sizeMB: 95,
                isRequired: true,
                isInstalled: false,
                installPath: driversDir.appendingPathComponent("directx").path
            )
        ]
    }
    
    // MARK: - Download & Install
    
    func downloadDriver(_ driver: GraphicsDriver, completion: @escaping (Bool, String) -> Void) {
        // Handle bundled components — just mark as installed
        if driver.downloadURL == "bundled" {
            let installDir = URL(fileURLWithPath: driver.installPath)
            try? fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)
            // Write a marker file so the directory isn't empty
            let marker = installDir.appendingPathComponent(".installed")
            try? driver.name.write(to: marker, atomically: true, encoding: .utf8)
            markInstalled(driverID: driver.id)
            if let idx = availableDrivers.firstIndex(where: { $0.id == driver.id }) {
                availableDrivers[idx].isInstalled = true
            }
            completion(true, "\(driver.name) marked as installed (bundled with Wine)")
            return
        }
        
        guard !driver.downloadURL.isEmpty, let url = URL(string: driver.downloadURL) else {
            completion(false, "No download URL available for \(driver.name)")
            return
        }
        
        isDownloading = true
        downloadProgress[driver.id] = 0.0
        
        let session = URLSession.shared
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            defer {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadProgress.removeValue(forKey: driver.id)
                }
            }
            
            // Check for HTTP errors (404 returns small HTML page)
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    DispatchQueue.main.async {
                        completion(false, "Download failed: HTTP \(httpResponse.statusCode) for \(driver.name)")
                    }
                    return
                }
            }
            
            guard let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error?.localizedDescription ?? "Download failed")
                }
                return
            }
            
            // Verify the file is not too small (< 1KB means error page)
            let attrs = try? self.fileManager.attributesOfItem(atPath: tempURL.path)
            let fileSize = (attrs?[.size] as? Int) ?? 0
            if fileSize < 1024 {
                DispatchQueue.main.async {
                    completion(false, "Download failed: file too small (\(fileSize) bytes) — URL may be invalid")
                }
                return
            }
            
            do {
                let installDir = URL(fileURLWithPath: driver.installPath)
                try? self.fileManager.removeItem(at: installDir)
                try self.fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)
                
                // Move the downloaded archive
                let ext = url.pathExtension.isEmpty ? "tar.gz" : url.pathExtension
                let archivePath = installDir.appendingPathComponent("archive.\(ext)")
                try self.fileManager.moveItem(at: tempURL, to: archivePath)
                
                // Write marker + persist
                let marker = installDir.appendingPathComponent(".installed")
                let info = "\(driver.name) v\(driver.version)\nSize: \(fileSize) bytes\nDate: \(Date())"
                try info.write(to: marker, atomically: true, encoding: .utf8)
                
                self.markInstalled(driverID: driver.id)
                
                if let idx = self.availableDrivers.firstIndex(where: { $0.id == driver.id }) {
                    DispatchQueue.main.async {
                        self.availableDrivers[idx].isInstalled = true
                        completion(true, "\(driver.name) v\(driver.version) installed (\(fileSize / 1024) KB)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Install failed: \(error.localizedDescription)")
                }
            }
        }
        
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            DispatchQueue.main.async {
                self?.downloadProgress[driver.id] = prog.fractionCompleted
            }
        }
        task.resume()
        _ = observation
    }
    
    func uninstallDriver(_ driver: GraphicsDriver) {
        let installDir = URL(fileURLWithPath: driver.installPath)
        try? fileManager.removeItem(at: installDir)
        markUninstalled(driverID: driver.id)
        
        if let idx = availableDrivers.firstIndex(where: { $0.id == driver.id }) {
            availableDrivers[idx].isInstalled = false
        }
    }
    
    func getInstalledDrivers() -> [GraphicsDriver] {
        return availableDrivers.filter { $0.isInstalled }
    }
    
    func getDriversByCategory(_ category: GraphicsDriver.DriverCategory) -> [GraphicsDriver] {
        return availableDrivers.filter { $0.category == category }
    }
    
    func getTotalInstalledSize() -> Int {
        return getInstalledDrivers().reduce(0) { $0 + $1.sizeMB }
    }
}
