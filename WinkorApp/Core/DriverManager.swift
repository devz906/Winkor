import Foundation

// Driver Manager: Downloads and manages GPU drivers, DirectX wrappers, and rendering components
// This is the equivalent of Winlator's driver/component download system

struct GraphicsDriver: Identifiable, Codable {
    let id: UUID
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
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isDownloading = false
    
    private let fileManager = FileManager.default
    
    var driversDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("drivers")
    }
    
    var mesaPath: String {
        driversDirectory.appendingPathComponent("mesa/libGL.dylib").path
    }
    
    var dxvkPath: String {
        driversDirectory.appendingPathComponent("dxvk/d3d11.dll").path
    }
    
    var virglPath: String {
        driversDirectory.appendingPathComponent("virgl/libvirgl.dylib").path
    }
    
    var turnipPath: String {
        driversDirectory.appendingPathComponent("turnip/libvulkan_freedreno.dylib").path
    }
    
    init() {
        try? fileManager.createDirectory(at: driversDirectory, withIntermediateDirectories: true)
        loadAvailableDrivers()
    }
    
    func loadAvailableDrivers() {
        availableDrivers = [
            // GPU Drivers
            GraphicsDriver(
                id: UUID(),
                name: "Turnip (Adreno Vulkan)",
                category: .gpu,
                version: "24.0.0",
                description: "Mesa Turnip Vulkan driver - provides native Vulkan support. Best performance for modern games. Translates Vulkan calls to Metal on iOS.",
                downloadURL: "https://github.com/nicknsy/turnip-ios/releases/download/v24.0/turnip-ios-arm64.tar.gz",
                sizeMB: 45,
                isRequired: false,
                isInstalled: fileManager.fileExists(atPath: turnipPath),
                installPath: driversDirectory.appendingPathComponent("turnip").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "VirGL (OpenGL)",
                category: .opengl,
                version: "1.0.0",
                description: "VirGL OpenGL renderer - translates OpenGL calls to Metal. Good compatibility with older games that use OpenGL.",
                downloadURL: "https://github.com/nicknsy/virgl-ios/releases/download/v1.0/virgl-ios-arm64.tar.gz",
                sizeMB: 32,
                isRequired: false,
                isInstalled: fileManager.fileExists(atPath: virglPath),
                installPath: driversDirectory.appendingPathComponent("virgl").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "Mesa (OpenGL/Vulkan)",
                category: .gpu,
                version: "24.0.0",
                description: "Mesa 3D Graphics Library - core graphics stack providing OpenGL and Vulkan implementations. Required for most games.",
                downloadURL: "https://github.com/nicknsy/mesa-ios/releases/download/v24.0/mesa-ios-arm64.tar.gz",
                sizeMB: 85,
                isRequired: true,
                isInstalled: fileManager.fileExists(atPath: mesaPath),
                installPath: driversDirectory.appendingPathComponent("mesa").path
            ),
            
            // DX Wrappers
            GraphicsDriver(
                id: UUID(),
                name: "DXVK",
                category: .dxWrapper,
                version: "2.3.1",
                description: "DirectX 9/10/11 to Vulkan translation layer. Essential for running DirectX games. Converts D3D calls to Vulkan which then goes to Metal.",
                downloadURL: "https://github.com/doitsujin/dxvk/releases/download/v2.3.1/dxvk-2.3.1.tar.gz",
                sizeMB: 28,
                isRequired: true,
                isInstalled: fileManager.fileExists(atPath: dxvkPath),
                installPath: driversDirectory.appendingPathComponent("dxvk").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "VKD3D-Proton",
                category: .dxWrapper,
                version: "2.12",
                description: "DirectX 12 to Vulkan translation layer. Required for DX12 games. Works with Turnip Vulkan driver.",
                downloadURL: "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v2.12/vkd3d-proton-2.12.tar.zst",
                sizeMB: 18,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("vkd3d").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "D8VK",
                category: .dxWrapper,
                version: "1.0",
                description: "DirectX 8 to Vulkan. For very old games that use DirectX 8.",
                downloadURL: "",
                sizeMB: 12,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("d8vk").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "WineD3D",
                category: .dxWrapper,
                version: "9.0",
                description: "Wine's built-in DirectX to OpenGL translation. Slower than DXVK but more compatible with some older games.",
                downloadURL: "",
                sizeMB: 15,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("wined3d").path
            ),
            
            // Vulkan
            GraphicsDriver(
                id: UUID(),
                name: "MoltenVK",
                category: .vulkan,
                version: "1.2.8",
                description: "Vulkan to Metal translation layer by Khronos. Bridges Vulkan API to Apple's Metal API. Core component for all Vulkan-based rendering.",
                downloadURL: "https://github.com/KhronosGroup/MoltenVK/releases/download/v1.2.8/MoltenVK-ios.tar.gz",
                sizeMB: 22,
                isRequired: true,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("moltenvk").path
            ),
            
            // Audio
            GraphicsDriver(
                id: UUID(),
                name: "PulseAudio",
                category: .audio,
                version: "16.1",
                description: "PulseAudio sound server for Wine audio output. Routes Windows audio to iOS audio system.",
                downloadURL: "",
                sizeMB: 8,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("pulseaudio").path
            ),
            
            // Input
            GraphicsDriver(
                id: UUID(),
                name: "XInput / DirectInput Bridge",
                category: .input,
                version: "1.0",
                description: "Gamepad input translation. Maps iOS game controllers to Windows XInput/DirectInput for game controller support.",
                downloadURL: "",
                sizeMB: 3,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("xinput").path
            ),
            
            // Runtimes
            GraphicsDriver(
                id: UUID(),
                name: "Visual C++ Runtime",
                category: .runtime,
                version: "2015-2022",
                description: "Microsoft Visual C++ Redistributable. Required by most Windows applications and games.",
                downloadURL: "",
                sizeMB: 35,
                isRequired: true,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("vcredist").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: ".NET Framework",
                category: .runtime,
                version: "4.8",
                description: ".NET Framework runtime. Required by many Windows applications.",
                downloadURL: "",
                sizeMB: 65,
                isRequired: false,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("dotnet").path
            ),
            GraphicsDriver(
                id: UUID(),
                name: "DirectX Runtime",
                category: .runtime,
                version: "June 2010",
                description: "DirectX End-User Runtime. Includes D3DX libraries and XAudio needed by many games.",
                downloadURL: "",
                sizeMB: 95,
                isRequired: true,
                isInstalled: false,
                installPath: driversDirectory.appendingPathComponent("directx").path
            )
        ]
    }
    
    // MARK: - Download & Install
    
    func downloadDriver(_ driver: GraphicsDriver, completion: @escaping (Bool, String) -> Void) {
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
            
            guard let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error?.localizedDescription ?? "Download failed")
                }
                return
            }
            
            do {
                let installDir = URL(fileURLWithPath: driver.installPath)
                try? self.fileManager.removeItem(at: installDir)
                try self.fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)
                
                // Move archive and extract (placeholder - real extraction needed)
                let archivePath = installDir.appendingPathComponent("archive.tar.gz")
                try self.fileManager.moveItem(at: tempURL, to: archivePath)
                
                // Mark as installed
                if let idx = self.availableDrivers.firstIndex(where: { $0.id == driver.id }) {
                    DispatchQueue.main.async {
                        self.availableDrivers[idx].isInstalled = true
                        completion(true, "\(driver.name) \(driver.version) installed successfully")
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
