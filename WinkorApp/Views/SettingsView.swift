import SwiftUI

// Settings View: Global app settings, JIT configuration, Wine version management

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingWineInstall = false
    @State private var showingBox64Install = false
    @State private var showingJITHelp = false
    @State private var installProgress: Double = 0
    @State private var installMessage = ""
    @State private var isInstalling = false
    
    var body: some View {
        NavigationView {
            Form {
                // JIT Status
                Section(header: Label("JIT Status", systemImage: "bolt.fill")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(appState.jitManager.isJITEnabled ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                                Text(appState.jitManager.status.rawValue)
                                    .font(.headline)
                            }
                            
                            Text(appState.jitManager.isJITEnabled
                                 ? "Box64 dynarec running at full speed"
                                 : "Box64 running in interpreter mode (slow)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Refresh") {
                            appState.jitManager.checkJITStatus()
                        }
                        .font(.caption)
                    }
                    
                    if !appState.jitManager.isJITEnabled {
                        ForEach(JITManager.JITMethod.allCases, id: \.self) { method in
                            Button(action: {
                                appState.jitManager.enableJIT(method: method) { success, message in
                                    installMessage = message
                                }
                            }) {
                                HStack {
                                    Image(systemName: "bolt.circle")
                                    VStack(alignment: .leading) {
                                        Text(method.rawValue)
                                            .font(.subheadline)
                                        Text(jitMethodDescription(method))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Button("How to enable JIT?") {
                        showingJITHelp = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                // System Info
                Section(header: Label("System", systemImage: "info.circle")) {
                    InfoRow(label: "RAM", value: appState.jitManager.getRAMString())
                    InfoRow(label: "CPU Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                    InfoRow(label: "Disk Free", value: FileSystemManager.shared.getAvailableDiskSpace())
                    InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
                    InfoRow(label: "Device", value: UIDevice.current.name)
                }
                
                // Wine Engine
                Section(header: Label("Wine Engine", systemImage: "wineglass")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(appState.wineEngine.isInstalled() ? "Installed" : "Not Installed")
                            .foregroundColor(appState.wineEngine.isInstalled() ? .green : .red)
                    }
                    
                    if !appState.wineEngine.isInstalled() {
                        Button("Install Wine") {
                            showingWineInstall = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    ForEach(WineEngine.WineVersion.allCases, id: \.self) { version in
                        Button(action: {
                            installWine(version: version)
                        }) {
                            HStack {
                                Text(version.rawValue)
                                Spacer()
                                if isInstalling {
                                    ProgressView(value: installProgress)
                                        .frame(width: 60)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isInstalling)
                    }
                }
                
                // Box64
                Section(header: Label("Box64 (x86-64 Emulator)", systemImage: "cpu")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(appState.box64Bridge.isInstalled() ? "Installed" : "Not Installed")
                            .foregroundColor(appState.box64Bridge.isInstalled() ? .green : .red)
                    }
                    
                    ForEach(appState.box64Bridge.availableReleases(), id: \.version) { release in
                        Button(action: {
                            installBox64(release: release)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Box64 \(release.version)")
                                    Text("\(release.size / 1_000_000) MB")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isInstalling {
                                    ProgressView(value: installProgress)
                                        .frame(width: 60)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isInstalling)
                    }
                }
                
                // Installed Components
                Section(header: Label("Installed Components", systemImage: "checkmark.circle")) {
                    ForEach(Array(appState.installedComponents.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key.capitalized)
                            Spacer()
                            Image(systemName: appState.installedComponents[key] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(appState.installedComponents[key] == true ? .green : .red)
                        }
                    }
                }
                
                // About
                Section(header: Label("About", systemImage: "star")) {
                    InfoRow(label: "App", value: "Winkor")
                    InfoRow(label: "Version", value: "1.0.0")
                    InfoRow(label: "Build", value: "1")
                    
                    Link(destination: URL(string: "https://github.com/ezzid29-coder/Winkor")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Winkor is a Windows emulator for iOS, inspired by Winlator (Android). It uses Box64 for x86-64 CPU translation, Wine for Windows API compatibility, DXVK for DirectX→Vulkan, and MoltenVK for Vulkan→Metal graphics.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Debug
                Section(header: Label("Debug", systemImage: "ant")) {
                    Button("Clear All Data") {
                        // Clear all containers and settings
                    }
                    .foregroundColor(.red)
                    
                    Button("Export Logs") {
                        // Export debug logs
                    }
                    
                    Button("Reset All Settings") {
                        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                    }
                    .foregroundColor(.red)
                }
                
                if !installMessage.isEmpty {
                    Section {
                        Text(installMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingJITHelp) {
                JITHelpView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Install Functions
    
    private func installWine(version: WineEngine.WineVersion) {
        isInstalling = true
        installProgress = 0
        installMessage = "Downloading \(version.rawValue)..."
        
        appState.wineEngine.downloadAndInstall(
            version: version,
            progress: { progress in
                installProgress = progress
            },
            completion: { success, message in
                isInstalling = false
                installMessage = message
                appState.checkInstalledComponents()
            }
        )
    }
    
    private func installBox64(release: Box64Bridge.Box64Release) {
        isInstalling = true
        installProgress = 0
        installMessage = "Downloading Box64 \(release.version)..."
        
        appState.box64Bridge.downloadAndInstall(
            release: release,
            progress: { progress in
                installProgress = progress
            },
            completion: { success, message in
                isInstalling = false
                installMessage = message
                appState.checkInstalledComponents()
            }
        )
    }
    
    private func jitMethodDescription(_ method: JITManager.JITMethod) -> String {
        switch method {
        case .sideJITServer: return "Companion app on PC enables JIT over WiFi"
        case .jitStreamer: return "iOS Shortcut-based JIT enabler"
        case .debuggerAttach: return "Connect to Xcode for debugger JIT"
        case .entitlement: return "Direct entitlement (jailbreak only)"
        case .altJIT: return "AltStore JIT support"
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - JIT Help View

struct JITHelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("JIT (Just-In-Time Compilation)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("JIT is REQUIRED for Box64's dynarec (dynamic recompiler) to work. Without JIT, Box64 runs in pure interpreter mode which is 10-50x slower.")
                        .font(.body)
                    
                    Divider()
                    
                    Group {
                        jitMethod(
                            title: "SideJITServer (Recommended)",
                            steps: [
                                "1. Install SideJITServer on your PC/Mac",
                                "2. Connect your iPhone to the same WiFi network",
                                "3. Run SideJITServer on your PC",
                                "4. Open Winkor - JIT will be enabled automatically",
                                "5. JIT stays enabled until app is closed"
                            ]
                        )
                        
                        jitMethod(
                            title: "JITStreamer",
                            steps: [
                                "1. Install the JITStreamer shortcut on your iPhone",
                                "2. Run the shortcut before opening Winkor",
                                "3. Open Winkor within 10 seconds"
                            ]
                        )
                        
                        jitMethod(
                            title: "AltStore / AltJIT",
                            steps: [
                                "1. Sideload Winkor using AltStore",
                                "2. Enable JIT from AltStore's app list",
                                "3. Winkor will have JIT on next launch"
                            ]
                        )
                        
                        jitMethod(
                            title: "Xcode Debugger",
                            steps: [
                                "1. Connect your iPhone to your Mac",
                                "2. Open the Winkor project in Xcode",
                                "3. Run the app from Xcode (debugger attaches JIT)"
                            ]
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("JIT Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    private func jitMethod(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)
            
            ForEach(steps, id: \.self) { step in
                Text(step)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
