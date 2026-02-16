import Foundation

// DLL Loader: Manages loading and resolving Windows DLLs
// When a Windows .exe tries to load a DLL, this resolver finds the right one
// in the Wine prefix or provides a stub implementation

class DLLLoader {
    
    struct LoadedDLL: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let baseAddress: UInt64
        let size: UInt64
        let exports: [String: UInt64]
        let isNative: Bool  // true = Wine-provided, false = Windows original
    }
    
    private var loadedDLLs: [String: LoadedDLL] = [:]
    private var searchPaths: [URL] = []
    private var dllOverrides: [String: DLLOverride] = [:]
    private var nextBaseAddress: UInt64 = 0x10000000
    
    enum DLLOverride: String, CaseIterable {
        case native = "native"      // Use Wine's version
        case builtin = "builtin"    // Use built-in stub
        case disabled = "disabled"  // Don't load
        case nativeBuiltin = "native,builtin" // Try native first, fall back to builtin
        case builtinNative = "builtin,native" // Try builtin first, fall back to native
    }
    
    init() {
        setupDefaultOverrides()
    }
    
    func configureSearchPaths(container: WineContainer) {
        let containerManager = ContainerManager()
        let driveC = containerManager.driveCPath(for: container)
        
        searchPaths = [
            driveC.appendingPathComponent("Windows/System32"),
            driveC.appendingPathComponent("Windows/SysWOW64"),
            driveC.appendingPathComponent("Windows"),
        ]
        
        // Add Wine lib paths
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        searchPaths.append(docs.appendingPathComponent("wine/lib/wine/x86_64-windows"))
        searchPaths.append(docs.appendingPathComponent("wine/lib/wine/i386-windows"))
        
        // Add DXVK override paths
        searchPaths.append(docs.appendingPathComponent("drivers/dxvk/x64"))
        searchPaths.append(docs.appendingPathComponent("drivers/dxvk/x32"))
    }
    
    private func setupDefaultOverrides() {
        // DXVK overrides - use native (DXVK) versions of DirectX DLLs
        dllOverrides["d3d9"] = .native
        dllOverrides["d3d10"] = .native
        dllOverrides["d3d10_1"] = .native
        dllOverrides["d3d10core"] = .native
        dllOverrides["d3d11"] = .native
        dllOverrides["dxgi"] = .native
        
        // VKD3D for DX12
        dllOverrides["d3d12"] = .native
        dllOverrides["d3d12core"] = .native
        
        // XInput
        dllOverrides["xinput1_3"] = .native
        dllOverrides["xinput1_4"] = .native
        dllOverrides["xinput9_1_0"] = .native
        
        // XAudio
        dllOverrides["xaudio2_7"] = .native
        dllOverrides["xaudio2_8"] = .native
        dllOverrides["xaudio2_9"] = .native
        
        // Wine builtins
        dllOverrides["ntdll"] = .builtin
        dllOverrides["kernel32"] = .builtin
        dllOverrides["user32"] = .builtin
        dllOverrides["gdi32"] = .builtin
        dllOverrides["advapi32"] = .builtin
        dllOverrides["msvcrt"] = .builtin
        dllOverrides["ucrtbase"] = .builtin
    }
    
    // MARK: - DLL Loading
    
    func loadDLL(name: String) -> LoadedDLL? {
        let normalizedName = name.lowercased()
        let baseName = normalizedName.hasSuffix(".dll") ? String(normalizedName.dropLast(4)) : normalizedName
        
        // Check if already loaded
        if let existing = loadedDLLs[baseName] {
            return existing
        }
        
        // Check overrides
        let override = dllOverrides[baseName] ?? .nativeBuiltin
        
        switch override {
        case .disabled:
            print("[DLLLoader] \(name) is disabled by override")
            return nil
        case .builtin:
            return loadBuiltinDLL(baseName)
        case .native:
            return loadNativeDLL(baseName) ?? loadBuiltinDLL(baseName)
        case .nativeBuiltin:
            return loadNativeDLL(baseName) ?? loadBuiltinDLL(baseName)
        case .builtinNative:
            return loadBuiltinDLL(baseName) ?? loadNativeDLL(baseName)
        }
    }
    
    private func loadNativeDLL(_ baseName: String) -> LoadedDLL? {
        let fileName = "\(baseName).dll"
        
        // Search paths for the DLL file
        for searchPath in searchPaths {
            let dllURL = searchPath.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: dllURL.path) {
                let dll = LoadedDLL(
                    name: baseName,
                    path: dllURL.path,
                    baseAddress: nextBaseAddress,
                    size: 0x10000,
                    exports: [:],
                    isNative: true
                )
                nextBaseAddress += 0x10000
                loadedDLLs[baseName] = dll
                print("[DLLLoader] Loaded native: \(fileName) at 0x\(String(dll.baseAddress, radix: 16))")
                return dll
            }
        }
        
        return nil
    }
    
    private func loadBuiltinDLL(_ baseName: String) -> LoadedDLL? {
        let dll = LoadedDLL(
            name: baseName,
            path: "builtin",
            baseAddress: nextBaseAddress,
            size: 0x1000,
            exports: getBuiltinExports(baseName),
            isNative: false
        )
        nextBaseAddress += 0x10000
        loadedDLLs[baseName] = dll
        print("[DLLLoader] Loaded builtin: \(baseName).dll at 0x\(String(dll.baseAddress, radix: 16))")
        return dll
    }
    
    private func getBuiltinExports(_ baseName: String) -> [String: UInt64] {
        // Return stub export addresses for common DLLs
        var exports: [String: UInt64] = [:]
        let base = nextBaseAddress
        
        switch baseName {
        case "kernel32":
            let funcs = ["GetProcAddress", "LoadLibraryA", "LoadLibraryW",
                        "GetModuleHandleA", "VirtualAlloc", "VirtualFree",
                        "GetCurrentProcess", "GetTickCount", "Sleep",
                        "CreateFileA", "ReadFile", "WriteFile", "CloseHandle",
                        "GetLastError", "SetLastError", "ExitProcess",
                        "HeapAlloc", "HeapFree", "GetProcessHeap"]
            for (i, name) in funcs.enumerated() {
                exports[name] = base + UInt64(i * 16)
            }
        case "user32":
            let funcs = ["CreateWindowExA", "ShowWindow", "GetMessageA",
                        "DispatchMessageA", "DefWindowProcA", "PostQuitMessage",
                        "MessageBoxA", "GetSystemMetrics", "GetDC", "ReleaseDC"]
            for (i, name) in funcs.enumerated() {
                exports[name] = base + UInt64(i * 16)
            }
        case "gdi32":
            let funcs = ["CreateDCA", "CreateCompatibleDC", "SelectObject",
                        "DeleteObject", "BitBlt", "GetDeviceCaps"]
            for (i, name) in funcs.enumerated() {
                exports[name] = base + UInt64(i * 16)
            }
        default:
            break
        }
        
        return exports
    }
    
    // MARK: - Public Interface
    
    func setOverride(dll: String, mode: DLLOverride) {
        let baseName = dll.lowercased().replacingOccurrences(of: ".dll", with: "")
        dllOverrides[baseName] = mode
    }
    
    func getOverrides() -> [String: DLLOverride] {
        return dllOverrides
    }
    
    func getLoadedDLLs() -> [LoadedDLL] {
        return Array(loadedDLLs.values)
    }
    
    func resolveImport(dll: String, function: String) -> UInt64? {
        let baseName = dll.lowercased().replacingOccurrences(of: ".dll", with: "")
        return loadedDLLs[baseName]?.exports[function]
    }
    
    func unloadAll() {
        loadedDLLs.removeAll()
        nextBaseAddress = 0x10000000
    }
    
    // Generate WINEDLLOVERRIDES environment variable string
    func generateDLLOverridesString() -> String {
        return dllOverrides.map { "\($0.key)=\($0.value.rawValue)" }.joined(separator: ";")
    }
}
