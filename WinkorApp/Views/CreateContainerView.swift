import SwiftUI

// Create Container View: Winlator-style container creation dialog
// Configure Windows version, GPU driver, resolution, DX wrapper, Box64 preset, etc.

struct CreateContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var windowsVersion = "Windows 10"
    @State private var graphicsDriver = "Turnip (Vulkan)"
    @State private var screenResolution = "1280x720"
    @State private var cpuCores = 4
    @State private var ramMB = 2048
    @State private var dxWrapper = "DXVK"
    @State private var box64Preset = "Default"
    @State private var isCreating = false
    @State private var showAdvanced = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    let windowsVersions = ["Windows 11", "Windows 10", "Windows 8.1", "Windows 7", "Windows XP"]
    let graphicsDrivers = ["Turnip (Vulkan)", "VirGL (OpenGL)", "Vulkan (MoltenVK)", "WineD3D (Software)"]
    let resolutions = ["640x480", "800x600", "1024x768", "1280x720", "1280x800", "1920x1080", "2560x1440"]
    let dxWrappers = ["DXVK", "DXVK + VKD3D", "WineD3D", "D8VK"]
    let box64Presets = ["Default", "Performance", "Gaming", "Compatibility", "Custom"]
    let cpuOptions = [1, 2, 4, 6, 8]
    let ramOptions = [512, 1024, 2048, 3072, 4096, 6144, 8192]
    
    var body: some View {
        NavigationView {
            Form {
                // Container Name
                Section(header: Label("Container Name", systemImage: "textformat")) {
                    TextField("My Container", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                // Windows Configuration
                Section(header: Label("Windows", systemImage: "window.shade.closed")) {
                    Picker("Windows Version", selection: $windowsVersion) {
                        ForEach(windowsVersions, id: \.self) { Text($0) }
                    }
                }
                
                // Graphics Configuration
                Section(header: Label("Graphics", systemImage: "gpu")) {
                    Picker("Graphics Driver", selection: $graphicsDriver) {
                        ForEach(graphicsDrivers, id: \.self) { Text($0) }
                    }
                    
                    Picker("DX Wrapper", selection: $dxWrapper) {
                        ForEach(dxWrappers, id: \.self) { Text($0) }
                    }
                    
                    Picker("Screen Resolution", selection: $screenResolution) {
                        ForEach(resolutions, id: \.self) { Text($0) }
                    }
                    
                    // Graphics pipeline explanation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Graphics Pipeline:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(pipelineDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Performance
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
                
                // Advanced
                Section(header: Label("Advanced", systemImage: "wrench.and.screwdriver")) {
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("These settings affect Box64 dynarec behavior")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Preset: \(box64Preset)")
                                .font(.caption)
                            
                            if box64Preset == "Gaming" {
                                Text("Optimized for: Large games, high FPS")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else if box64Preset == "Compatibility" {
                                Text("Optimized for: Maximum compatibility, lower FPS")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else if box64Preset == "Performance" {
                                Text("Optimized for: Speed, may break some apps")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Create Button
                Section {
                    Button(action: createContainer) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "plus.circle.fill")
                            Text(isCreating ? "Creating..." : "Create Container")
                        }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(name.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(12)
                    }
                    .disabled(name.isEmpty || isCreating)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("New Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("Container Creation Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var pipelineDescription: String {
        switch dxWrapper {
        case "DXVK":
            return "DirectX 9/10/11 → DXVK → Vulkan → MoltenVK → Metal → GPU"
        case "DXVK + VKD3D":
            return "DirectX 9-12 → DXVK/VKD3D → Vulkan → MoltenVK → Metal → GPU"
        case "WineD3D":
            return "DirectX → WineD3D → OpenGL → VirGL → Metal → GPU"
        case "D8VK":
            return "DirectX 8 → D8VK → Vulkan → MoltenVK → Metal → GPU"
        default:
            return "DirectX → Vulkan → Metal → GPU"
        }
    }
    
    private func createContainer() {
        guard !name.isEmpty else { return }
        isCreating = true
        
        let container = WineContainer(
            name: name,
            windowsVersion: windowsVersion,
            graphicsDriver: graphicsDriver,
            screenResolution: screenResolution,
            cpuCores: cpuCores,
            ramMB: ramMB,
            dxwrapperVersion: dxWrapper,
            box64Preset: box64Preset
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = appState.containerManager.createContainer(container)
            
            DispatchQueue.main.async {
                isCreating = false
                if success {
                    appState.loadContainers()
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = "Failed to create container. Check the console for details."
                    showError = true
                }
            }
        }
    }
}
