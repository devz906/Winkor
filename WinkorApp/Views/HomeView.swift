import SwiftUI
import UniformTypeIdentifiers

// Home View: Main container list - like Winlator's home screen
// Shows all Wine containers, lets user create/edit/run them

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreateContainer = false
    @State private var showingRunView = false
    @State private var selectedContainer: WineContainer?
    @State private var showingContainerSettings = false
    @State private var showingFilePicker = false
    @State private var selectedEXE: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Status Banner
                    statusBanner
                    
                    // Quick Actions
                    quickActions
                    
                    // Container List
                    containerList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Winkor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateContainer = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingCreateContainer) {
                CreateContainerView()
            }
            .sheet(isPresented: $showingContainerSettings) {
                if let container = selectedContainer {
                    ContainerSettingsView(container: container)
                }
            }
            .fullScreenCover(isPresented: $showingRunView) {
                if let container = selectedContainer {
                    DesktopView(container: container, exePath: selectedEXE)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Status Banner
    
    private var statusBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Winkor")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Windows Emulator for iOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // JIT Status
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.jitManager.isJITEnabled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(appState.jitManager.isJITEnabled ? "JIT ON" : "JIT OFF")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    Text(appState.jitManager.getRAMString())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Engine status
            if !appState.isEngineReady {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Some components missing — go to Components tab to install")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.rectangle.fill",
                    title: "New Container",
                    color: .blue
                ) {
                    showingCreateContainer = true
                }
                
                QuickActionButton(
                    icon: "doc.badge.arrow.up.fill",
                    title: "Run EXE",
                    color: .green
                ) {
                    showingFilePicker = true
                }
                
                QuickActionButton(
                    icon: "arrow.down.circle.fill",
                    title: "Install App",
                    color: .purple
                ) {
                    showingFilePicker = true
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            EXEDocumentPicker(selectedFile: $selectedEXE)
        }
        .onChange(of: selectedEXE) { newValue in
            if newValue != nil && !appState.containers.isEmpty {
                selectedContainer = appState.containers.first
                showingRunView = true
            }
        }
    }
    
    // MARK: - Container List
    
    private var containerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Containers")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(appState.containers.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if appState.containers.isEmpty {
                emptyContainerView
            } else {
                ForEach(appState.containers) { container in
                    ContainerCard(
                        container: container,
                        onRun: {
                            selectedContainer = container
                            showingRunView = true
                        },
                        onSettings: {
                            selectedContainer = container
                            showingContainerSettings = true
                        },
                        onDelete: {
                            appState.containerManager.deleteContainer(container)
                            appState.loadContainers()
                        }
                    )
                }
            }
        }
    }
    
    private var emptyContainerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Containers")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Create a container to start running Windows applications")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingCreateContainer = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Container")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Container Card

struct ContainerCard: View {
    let container: WineContainer
    let onRun: () -> Void
    let onSettings: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Container icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(containerColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundColor(containerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(container.name)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Label(container.windowsVersion, systemImage: "window.shade.closed")
                        Label(container.graphicsDriver, systemImage: "gpu")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Label(container.screenResolution, systemImage: "rectangle.dashed")
                        Label("\(container.cpuCores) cores", systemImage: "cpu")
                        Label("\(container.ramMB) MB", systemImage: "memorychip")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Run button
                    Button(action: onRun) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                    
                    // Last used
                    if let lastUsed = container.lastUsedAt {
                        Text(timeAgoString(lastUsed))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Bottom actions
            HStack {
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.caption)
                }
                
                Spacer()
                
                Text(container.dxwrapperVersion)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                
                Text(container.box64Preset)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .alert("Delete Container?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(container.name)\" and all its data.")
        }
    }
    
    private var containerColor: Color {
        switch container.graphicsDriver {
        case let g where g.contains("Turnip"): return .orange
        case let g where g.contains("VirGL"): return .green
        case let g where g.contains("Vulkan"): return .red
        default: return .blue
        }
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - EXE Document Picker

struct EXEDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFile: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.exe, UTType.msi, UTType.data].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: EXEDocumentPicker
        init(_ parent: EXEDocumentPicker) { self.parent = parent }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedFile = urls.first
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
