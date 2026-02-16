import SwiftUI
import Foundation
import UniformTypeIdentifiers

@main
struct WinkorApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var containers: [WineContainer] = []
    @Published var selectedContainer: WineContainer?
    @Published var isEngineReady = false
    @Published var downloadedDrivers: [GraphicsDriver] = []
    @Published var installedComponents: [String: Bool] = [:]
    
    let containerManager = ContainerManager()
    let driverManager = DriverManager()
    let box64Bridge = Box64Bridge()
    let jitManager = JITManager()
    let wineEngine = WineEngine()
    
    init() {
        loadContainers()
        checkInstalledComponents()
    }
    
    func loadContainers() {
        containers = containerManager.listContainers()
    }
    
    func checkInstalledComponents() {
        installedComponents["box64"] = box64Bridge.isInstalled()
        installedComponents["wine"] = wineEngine.isInstalled()
        installedComponents["mesa"] = FileManager.default.fileExists(atPath: driverManager.mesaPath)
        installedComponents["dxvk"] = FileManager.default.fileExists(atPath: driverManager.dxvkPath)
        installedComponents["virgl"] = FileManager.default.fileExists(atPath: driverManager.virglPath)
        
        let allReady = installedComponents.values.allSatisfy { $0 }
        isEngineReady = allReady
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Containers")
                }
                .tag(0)
            
            DriverManagerView()
                .tabItem {
                    Image(systemName: "cpu")
                    Text("Components")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.orange)
    }
}

extension UTType {
    static let exe = UTType(filenameExtension: "exe") ?? .data
    static let msi = UTType(filenameExtension: "msi") ?? .data
}
