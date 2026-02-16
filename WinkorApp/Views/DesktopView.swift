import SwiftUI
import MetalKit
import UniformTypeIdentifiers

// Desktop View: The Windows desktop environment that appears when running a container
// This is where the Wine output is displayed, with a taskbar and virtual desktop

struct DesktopView: View {
    let container: WineContainer
    let exePath: URL?
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var processManager = ProcessManager()
    @State private var showingConsole = true
    @State private var showingFileImport = false
    @State private var showingPEInfo = false
    @State private var consoleOutput: [String] = []
    @State private var selectedEXEForImport: URL?
    @State private var showingOnScreenControls = true
    @State private var peInfo = ""
    
    var body: some View {
        ZStack {
            // Background - Metal rendering surface (in production, MTKView goes here)
            Color.black
                .ignoresSafeArea()
            
            // Windows Desktop simulation
            VStack(spacing: 0) {
                // Top bar with controls
                topBar
                
                // Main display area
                ZStack {
                    // Desktop background
                    LinearGradient(
                        colors: [Color(red: 0, green: 0.47, blue: 0.84),
                                Color(red: 0, green: 0.28, blue: 0.63)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    if processManager.isRunning {
                        // Show console/app output
                        if showingConsole {
                            consoleView
                        }
                    } else {
                        // Desktop icons
                        desktopIcons
                    }
                    
                    // On-screen gamepad controls
                    if showingOnScreenControls && processManager.isRunning {
                        onScreenControls
                    }
                }
                
                // Taskbar
                taskbar
            }
        }
        .onAppear {
            if let exe = exePath {
                launchEXE(exe.path)
            }
        }
        .sheet(isPresented: $showingFileImport) {
            EXEDocumentPicker(selectedFile: $selectedEXEForImport)
        }
        .onChange(of: selectedEXEForImport) { newValue in
            if let url = newValue {
                launchEXE(url.path)
            }
        }
        .sheet(isPresented: $showingPEInfo) {
            PEInfoView(info: peInfo)
        }
        .statusBarHidden(true)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if processManager.isRunning {
                HStack(spacing: 12) {
                    Text("\(processManager.fps) FPS")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text(processManager.currentProcessName)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingConsole.toggle() }) {
                    Image(systemName: "terminal")
                        .foregroundColor(.white)
                }
                
                Button(action: { showingOnScreenControls.toggle() }) {
                    Image(systemName: "gamecontroller")
                        .foregroundColor(.white)
                }
                
                if processManager.isRunning {
                    Button(action: { processManager.stop() }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Desktop Icons
    
    private var desktopIcons: some View {
        VStack {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 16) {
                    DesktopIconItem(icon: "doc.badge.arrow.up", title: "Run EXE") {
                        showingFileImport = true
                    }
                    
                    DesktopIconItem(icon: "folder.fill", title: "Files") {
                        // Open file explorer
                    }
                    
                    DesktopIconItem(icon: "terminal.fill", title: "CMD") {
                        launchEXE("cmd.exe")
                    }
                }
                
                VStack(spacing: 16) {
                    DesktopIconItem(icon: "gearshape.fill", title: "Control\nPanel") {
                        launchEXE("control.exe")
                    }
                    
                    DesktopIconItem(icon: "doc.text.fill", title: "Notepad") {
                        launchEXE("notepad.exe")
                    }
                    
                    DesktopIconItem(icon: "info.circle.fill", title: "PE Info") {
                        showingFileImport = true
                    }
                }
                
                Spacer()
            }
            .padding(20)
            
            Spacer()
        }
    }
    
    // MARK: - Console View
    
    private var consoleView: some View {
        VStack(spacing: 0) {
            // Console title bar
            HStack {
                Image(systemName: "terminal")
                Text("Winkor Console")
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: { showingConsole = false }) {
                    Image(systemName: "minus.circle")
                }
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.8))
            
            // Console output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(consoleOutput.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(lineColor(for: line))
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: consoleOutput.count) { _ in
                    if let last = consoleOutput.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .background(Color.black.opacity(0.9))
        }
        .cornerRadius(8)
        .padding()
        .frame(maxHeight: 300)
    }
    
    private func lineColor(for line: String) -> Color {
        if line.contains("[Error]") || line.contains("ERROR") { return .red }
        if line.contains("WARNING") || line.contains("[Winkor]") { return .yellow }
        if line.contains("[Wine]") { return .purple }
        if line.contains("[Box64]") { return .cyan }
        if line.contains("[Graphics]") { return .orange }
        if line.contains("[DXVK]") { return .mint }
        return .green
    }
    
    // MARK: - On-Screen Controls
    
    private var onScreenControls: some View {
        VStack {
            Spacer()
            HStack {
                // D-pad
                VStack(spacing: 0) {
                    GamepadButton(icon: "chevron.up")
                    HStack(spacing: 20) {
                        GamepadButton(icon: "chevron.left")
                        GamepadButton(icon: "chevron.down")
                        GamepadButton(icon: "chevron.right")
                    }
                }
                .padding()
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 4) {
                    GamepadButton(icon: "y.circle.fill")
                    HStack(spacing: 20) {
                        GamepadButton(icon: "x.circle.fill")
                        GamepadButton(icon: "b.circle.fill")
                    }
                    GamepadButton(icon: "a.circle.fill")
                }
                .padding()
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Taskbar
    
    private var taskbar: some View {
        HStack(spacing: 8) {
            // Start button
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption)
                    Text("Start")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(4)
            }
            
            Divider()
                .frame(height: 20)
            
            // Running processes
            if processManager.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "app.fill")
                        .font(.caption2)
                    Text(processManager.currentProcessName)
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .cornerRadius(4)
            }
            
            Spacer()
            
            // System tray
            HStack(spacing: 6) {
                Image(systemName: "wifi")
                    .font(.caption2)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2)
                Text(Date(), style: .time)
                    .font(.system(.caption2, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
    }
    
    // MARK: - Launch
    
    private func launchEXE(_ path: String) {
        consoleOutput.removeAll()
        consoleOutput.append("[Winkor] ═══════════════════════════════════")
        consoleOutput.append("[Winkor] Starting Winkor Engine...")
        consoleOutput.append("[Winkor] Container: \(container.name)")
        consoleOutput.append("[Winkor] ═══════════════════════════════════")
        
        // Analyze PE if it's a real file
        if FileManager.default.fileExists(atPath: path) {
            let peLoader = PELoader()
            if let pe = peLoader.loadFromPath(path) {
                consoleOutput.append("[PE] Architecture: \(pe.architectureString)")
                consoleOutput.append("[PE] Subsystem: \(pe.subsystemString)")
                consoleOutput.append("[PE] 64-bit: \(pe.is64Bit)")
                peInfo = peLoader.getInfoString(for: pe)
            }
        }
        
        processManager.launch(exePath: path, in: container) { message in
            consoleOutput.append(message)
        }
        showingConsole = true
    }
}

// MARK: - Helper Views

struct DesktopIconItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black, radius: 2)
            }
            .frame(width: 60)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GamepadButton: View {
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(.white.opacity(0.6))
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
    }
}

struct PEInfoView: View {
    let info: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(info)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("PE File Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
