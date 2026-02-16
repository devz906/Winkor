import SwiftUI

// Driver Manager View: Download and manage GPU drivers, DX wrappers, runtimes
// This is the equivalent of Winlator's component download screen
// Users can download: Turnip, VirGL, Mesa, DXVK, VKD3D, MoltenVK, runtimes, etc.

struct DriverManagerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var driverManager = DriverManager()
    @State private var selectedCategory: GraphicsDriver.DriverCategory?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Status header
                    statusHeader
                    
                    // Category filter
                    categoryFilter
                    
                    // Component sections
                    ForEach(GraphicsDriver.DriverCategory.allCases, id: \.self) { category in
                        if selectedCategory == nil || selectedCategory == category {
                            let drivers = driverManager.getDriversByCategory(category)
                            if !drivers.isEmpty {
                                driverSection(category: category, drivers: drivers)
                            }
                        }
                    }
                    
                    // Info section
                    graphicsPipelineInfo
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Components")
            .alert("Download", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Components & Drivers")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    let installed = driverManager.getInstalledDrivers().count
                    let total = driverManager.availableDrivers.count
                    Text("\(installed)/\(total) installed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Disk Usage")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(driverManager.getTotalInstalledSize()) MB")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Free: \(FileSystemManager.shared.getAvailableDiskSpace())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Required components check
            let required = driverManager.availableDrivers.filter { $0.isRequired }
            let missingRequired = required.filter { !$0.isInstalled }
            
            if !missingRequired.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading) {
                        Text("Missing required components:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(missingRequired.map(\.name).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Install All") {
                        installAllRequired()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All required components installed")
                        .font(.caption)
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                
                ForEach(GraphicsDriver.DriverCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Driver Section
    
    private func driverSection(category: GraphicsDriver.DriverCategory, drivers: [GraphicsDriver]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon(category))
                    .foregroundColor(categoryColor(category))
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(drivers.filter(\.isInstalled).count)/\(drivers.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(drivers) { driver in
                DriverCard(
                    driver: driver,
                    downloadProgress: driverManager.downloadProgress[driver.id],
                    onDownload: {
                        driverManager.downloadDriver(driver) { success, message in
                            alertMessage = message
                            showingAlert = true
                            appState.checkInstalledComponents()
                        }
                    },
                    onUninstall: {
                        driverManager.uninstallDriver(driver)
                        appState.checkInstalledComponents()
                    }
                )
            }
        }
    }
    
    // MARK: - Graphics Pipeline Info
    
    private var graphicsPipelineInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Graphics Work")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                PipelineRow(
                    title: "DirectX Games (most games)",
                    pipeline: "Game → DXVK → Vulkan → MoltenVK → Metal → GPU",
                    color: .orange
                )
                PipelineRow(
                    title: "DirectX 12 Games",
                    pipeline: "Game → VKD3D-Proton → Vulkan → MoltenVK → Metal → GPU",
                    color: .red
                )
                PipelineRow(
                    title: "OpenGL Games",
                    pipeline: "Game → VirGL → Metal → GPU",
                    color: .green
                )
                PipelineRow(
                    title: "Vulkan Games",
                    pipeline: "Game → MoltenVK → Metal → GPU",
                    color: .purple
                )
            }
            
            Text("Box64 translates x86-64 CPU instructions to ARM64.\nWine translates Windows API calls to iOS equivalents.\nDXVK/VirGL translate graphics calls.\nMoltenVK bridges Vulkan to Metal.\nMetal renders on the iOS GPU.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func installAllRequired() {
        let missing = driverManager.availableDrivers.filter { $0.isRequired && !$0.isInstalled }
        for driver in missing {
            driverManager.downloadDriver(driver) { success, message in
                print("[DriverManager] \(message)")
                appState.checkInstalledComponents()
            }
        }
    }
    
    private func categoryIcon(_ cat: GraphicsDriver.DriverCategory) -> String {
        switch cat {
        case .gpu: return "gpu"
        case .dxWrapper: return "cube.transparent"
        case .opengl: return "paintbrush"
        case .vulkan: return "bolt.fill"
        case .audio: return "speaker.wave.2.fill"
        case .input: return "gamecontroller"
        case .runtime: return "gearshape.2"
        }
    }
    
    private func categoryColor(_ cat: GraphicsDriver.DriverCategory) -> Color {
        switch cat {
        case .gpu: return .orange
        case .dxWrapper: return .purple
        case .opengl: return .green
        case .vulkan: return .red
        case .audio: return .blue
        case .input: return .mint
        case .runtime: return .gray
        }
    }
}

// MARK: - Driver Card

struct DriverCard: View {
    let driver: GraphicsDriver
    let downloadProgress: Double?
    let onDownload: () -> Void
    let onUninstall: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(driver.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if driver.isRequired {
                            Text("REQUIRED")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("v\(driver.version) • \(driver.sizeMB) MB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(driver.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if driver.isInstalled {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Button("Remove") {
                            onUninstall()
                        }
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                } else if let progress = downloadProgress {
                    VStack(spacing: 4) {
                        ProgressView(value: progress)
                            .frame(width: 60)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                    }
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 3)
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.03), radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PipelineRow: View {
    let title: String
    let pipeline: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(pipeline)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .cornerRadius(6)
    }
}
