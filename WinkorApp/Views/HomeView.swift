import SwiftUI
import UIKit

struct HomeView: View {
    @State private var containers: [String] = []
    @State private var selectedContainer: String = "default"
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var runningProcesses: [String] = []
    @State private var isWineReady = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Wine Status
                wineStatusView
                
                // Container Management
                containerManagementView
                
                // File Management
                fileManagementView
                
                // Process Management
                processManagementView
                
                Spacer()
            }
            .padding()
            .navigationTitle("Winkor - Windows Emulator")
            .onAppear {
                loadData()
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker { url in
                handleFileSelection(url)
            }
        }
        .alert("Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var wineStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wine Engine Status")
                .font(.headline)
            
            HStack {
                Image(systemName: isWineReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isWineReady ? .green : .red)
                Text(isWineReady ? "Wine Ready" : "Wine Not Ready")
                    .foregroundColor(isWineReady ? .green : .red)
            }
            
            if !isWineReady {
                Button("Initialize Wine") {
                    initializeWine()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var containerManagementView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Container Management")
                .font(.headline)
            
            Picker("Container", selection: $selectedContainer) {
                ForEach(containers, id: \.self) { container in
                    Text(container).tag(container)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                Button("Create Container") {
                    createNewContainer()
                }
                
                Button("Refresh") {
                    loadContainers()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var fileManagementView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Management")
                .font(.headline)
            
            Button("Import EXE File") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            
            Text("Select a Windows .exe file to import and run")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var processManagementView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Running Processes")
                .font(.headline)
            
            if runningProcesses.isEmpty {
                Text("No processes running")
                    .foregroundColor(.secondary)
            } else {
                ForEach(runningProcesses, id: \.self) { process in
                    HStack {
                        Text(process)
                        Spacer()
                        Button("Terminate") {
                            terminateProcess(process)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func loadData() {
        isWineReady = WineEngine.shared.isWineReady()
        loadContainers()
        loadRunningProcesses()
    }
    
    private func initializeWine() {
        WineEngine.shared.setupWineContainer()
        isWineReady = WineEngine.shared.isWineReady()
        
        if isWineReady {
            alertMessage = "Wine initialized successfully!"
            showingAlert = true
            
            // Create default container
            createNewContainer()
        } else {
            alertMessage = "Failed to initialize Wine"
            showingAlert = true
        }
    }
    
    private func loadContainers() {
        containers = ContainerManager.shared.listContainers()
        if containers.isEmpty && isWineReady {
            createNewContainer()
        }
    }
    
    private func createNewContainer() {
        let containerName = "container_\(containers.count + 1)"
        
        if ContainerManager.shared.createContainer(name: containerName) {
            containers = ContainerManager.shared.listContainers()
            selectedContainer = containerName
            alertMessage = "Container '\(containerName)' created successfully!"
        } else {
            alertMessage = "Failed to create container"
        }
        showingAlert = true
    }
    
    private func loadRunningProcesses() {
        runningProcesses = ProcessManager.shared.getRunningProcesses()
    }
    
    private func handleFileSelection(_ url: URL) {
        let exePath = url.path
        
        // Copy to container and execute
        if ProcessManager.shared.executeExeInContainer(exePath, containerName: selectedContainer) {
            alertMessage = "EXE file imported and executed successfully!"
        } else {
            alertMessage = "Failed to execute EXE file"
        }
        showingAlert = true
        
        loadRunningProcesses()
    }
    
    private func terminateProcess(_ processName: String) {
        if ProcessManager.shared.terminateProcess(processName) {
            alertMessage = "Process terminated successfully!"
        } else {
            alertMessage = "Failed to terminate process"
        }
        showingAlert = true
        loadRunningProcesses()
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}
