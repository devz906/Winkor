import SwiftUI

// Container Settings View: Edit an existing container's configuration
// Mirrors Winlator's container edit screen with GPU, CPU, DX wrapper, Wine settings

struct ContainerSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    let container: WineContainer
    
    @State private var name: String
    @State private var windowsVersion: String
    @State private var graphicsDriver: String
    @State private var screenResolution: String
    @State private var cpuCores: Int
    @State private var ramMB: Int
    @State private var dxWrapper: String
    @State private var box64Preset: String
    @State private var showingDLLOverrides = false
    @State private var showingEnvVars = false
    @State private var customEnvKey = ""
    @State private var customEnvValue = ""
    @State private var customEnvVars: [String: String]
    
    let windowsVersions = ["Windows 11", "Windows 10", "Windows 8.1", "Windows 7", "Windows XP"]
    let graphicsDrivers = ["Turnip (Vulkan)", "VirGL (OpenGL)", "Vulkan (MoltenVK)", "WineD3D (Software)"]
    let resolutions = ["640x480", "800x600", "1024x768", "1280x720", "1280x800", "1920x1080", "2560x1440"]
    let dxWrappers = ["DXVK", "DXVK + VKD3D", "WineD3D", "D8VK"]
    let box64Presets = ["Default", "Performance", "Gaming", "Compatibility", "Custom"]
    let cpuOptions = [1, 2, 4, 6, 8]
    let ramOptions = [512, 1024, 2048, 3072, 4096, 6144, 8192]
    
    init(container: WineContainer) {
        self.container = container
        self._name = State(initialValue: container.name)
        self._windowsVersion = State(initialValue: container.windowsVersion)
        self._graphicsDriver = State(initialValue: container.graphicsDriver)
        self._screenResolution = State(initialValue: container.screenResolution)
        self._cpuCores = State(initialValue: container.cpuCores)
        self._ramMB = State(initialValue: container.ramMB)
        self._dxWrapper = State(initialValue: container.dxwrapperVersion)
        self._box64Preset = State(initialValue: container.box64Preset)
        self._customEnvVars = State(initialValue: container.customEnvVars)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Label("General", systemImage: "info.circle")) {
                    TextField("Container Name", text: $name)
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(container.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Disk Usage")
                        Spacer()
                        Text(FileSystemManager.shared.getContainerSize(container: container))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Label("Windows", systemImage: "window.shade.closed")) {
                    Picker("Windows Version", selection: $windowsVersion) {
                        ForEach(windowsVersions, id: \.self) { Text($0) }
                    }
                }
                
                Section(header: Label("Graphics", systemImage: "gpu")) {
                    Picker("Graphics Driver", selection: $graphicsDriver) {
                        ForEach(graphicsDrivers, id: \.self) { Text($0) }
                    }
                    
                    Picker("DX Wrapper", selection: $dxWrapper) {
                        ForEach(dxWrappers, id: \.self) { Text($0) }
                    }
                    
                    Picker("Resolution", selection: $screenResolution) {
                        ForEach(resolutions, id: \.self) { Text($0) }
                    }
                }
                
                Section(header: Label("Performance", systemImage: "speedometer")) {
                    Picker("Box64 Preset", selection: $box64Preset) {
                        ForEach(box64Presets, id: \.self) { Text($0) }
                    }
                    
                    Picker("CPU Cores", selection: $cpuCores) {
                        ForEach(cpuOptions, id: \.self) { Text("\($0) cores") }
                    }
                    
                    Picker("RAM", selection: $ramMB) {
                        ForEach(ramOptions, id: \.self) { Text("\($0) MB") }
                    }
                }
                
                Section(header: Label("DLL Overrides", systemImage: "doc.on.doc")) {
                    Button("Manage DLL Overrides") {
                        showingDLLOverrides = true
                    }
                    
                    Text("Controls which DLLs use DXVK/Wine native vs Windows originals")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Label("Environment Variables", systemImage: "terminal")) {
                    ForEach(Array(customEnvVars.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text(customEnvVars[key] ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Button(action: { customEnvVars.removeValue(forKey: key) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("KEY", text: $customEnvKey)
                            .font(.system(.caption, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                        TextField("value", text: $customEnvValue)
                            .font(.system(.caption, design: .monospaced))
                        Button(action: {
                            if !customEnvKey.isEmpty {
                                customEnvVars[customEnvKey] = customEnvValue
                                customEnvKey = ""
                                customEnvValue = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Danger zone
                Section(header: Label("Danger Zone", systemImage: "exclamationmark.triangle")) {
                    Button("Reset Wine Prefix") {
                        // Reset prefix
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Shader Cache") {
                        appState.box64Bridge.clearDynarecCache(for: container)
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reinstall DXVK") {
                        appState.wineEngine.installDXVK(in: container) { _ in }
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Container Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingDLLOverrides) {
                DLLOverridesView()
            }
        }
    }
    
    private func saveChanges() {
        var containers = appState.containerManager.listContainers()
        if let idx = containers.firstIndex(where: { $0.id == container.id }) {
            containers[idx].name = name
            containers[idx].windowsVersion = windowsVersion
            containers[idx].graphicsDriver = graphicsDriver
            containers[idx].screenResolution = screenResolution
            containers[idx].cpuCores = cpuCores
            containers[idx].ramMB = ramMB
            containers[idx].dxwrapperVersion = dxWrapper
            containers[idx].box64Preset = box64Preset
            containers[idx].customEnvVars = customEnvVars
            appState.containerManager.saveContainers(containers)
            appState.loadContainers()
        }
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - DLL Overrides View

struct DLLOverridesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var dllLoader = DLLLoader()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("DXVK Overrides (DirectX → Vulkan)")) {
                    ForEach(["d3d9", "d3d10", "d3d10_1", "d3d10core", "d3d11", "dxgi"], id: \.self) { dll in
                        DLLOverrideRow(
                            dllName: dll,
                            currentMode: dllLoader.getOverrides()[dll]?.rawValue ?? "native",
                            onChange: { mode in
                                if let override = DLLLoader.DLLOverride(rawValue: mode) {
                                    dllLoader.setOverride(dll: dll, mode: override)
                                }
                            }
                        )
                    }
                }
                
                Section(header: Text("VKD3D Overrides (DirectX 12 → Vulkan)")) {
                    ForEach(["d3d12", "d3d12core"], id: \.self) { dll in
                        DLLOverrideRow(
                            dllName: dll,
                            currentMode: dllLoader.getOverrides()[dll]?.rawValue ?? "native",
                            onChange: { mode in
                                if let override = DLLLoader.DLLOverride(rawValue: mode) {
                                    dllLoader.setOverride(dll: dll, mode: override)
                                }
                            }
                        )
                    }
                }
                
                Section(header: Text("Wine Core DLLs")) {
                    ForEach(["ntdll", "kernel32", "user32", "gdi32", "advapi32", "msvcrt"], id: \.self) { dll in
                        DLLOverrideRow(
                            dllName: dll,
                            currentMode: dllLoader.getOverrides()[dll]?.rawValue ?? "builtin",
                            onChange: { mode in
                                if let override = DLLLoader.DLLOverride(rawValue: mode) {
                                    dllLoader.setOverride(dll: dll, mode: override)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("DLL Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct DLLOverrideRow: View {
    let dllName: String
    let currentMode: String
    let onChange: (String) -> Void
    
    let modes = ["native", "builtin", "native,builtin", "builtin,native", "disabled"]
    
    var body: some View {
        HStack {
            Text("\(dllName).dll")
                .font(.system(.body, design: .monospaced))
            Spacer()
            Menu(currentMode) {
                ForEach(modes, id: \.self) { mode in
                    Button(mode) { onChange(mode) }
                }
            }
            .font(.caption)
        }
    }
}
