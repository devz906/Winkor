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
    @State private var showingConsole = false
    @State private var showingAppWindow = true
    @State private var appWindowMaximized = false
    @StateObject private var metalRenderer = MetalRenderer()
    @State private var consoleOutput: [String] = []
    @State private var selectedEXEForImport: URL?
    @State private var showingOnScreenControls = true
    @State private var peInfo = ""
    
    var body: some View {
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
                
                // Desktop icons (visible when no maximized window)
                if !processManager.isRunning || !showingAppWindow || !appWindowMaximized {
                    desktopIcons
                }
                
                // App window when running
                if processManager.isRunning && showingAppWindow {
                    appWindow
                }
                
                // Console overlay
                if showingConsole {
                    VStack {
                        Spacer()
                        consoleView
                    }
                }
                
                // On-screen gamepad controls
                if showingOnScreenControls && processManager.isRunning {
                    onScreenControls
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            // Taskbar
            taskbar
        }
        .background(Color.black)
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
    
    // MARK: - App Window
    
    private var appWindow: some View {
        VStack(spacing: 0) {
            // Windows-style title bar
            HStack(spacing: 0) {
                Image(systemName: "app.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.leading, 8)
                
                Text(processManager.currentProcessName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.leading, 6)
                
                Spacer()
                
                // Window control buttons
                HStack(spacing: 0) {
                    Button(action: {
                        showingAppWindow = false
                    }) {
                        Image(systemName: "minus")
                            .font(.caption2)
                            .frame(width: 36, height: 28)
                            .foregroundColor(.white)
                    }
                    .background(Color.white.opacity(0.001))
                    
                    Button(action: {
                        appWindowMaximized.toggle()
                    }) {
                        Image(systemName: appWindowMaximized ? "square.on.square" : "square")
                            .font(.caption2)
                            .frame(width: 36, height: 28)
                            .foregroundColor(.white)
                    }
                    .background(Color.white.opacity(0.001))
                    
                    Button(action: {
                        processManager.stop()
                        showingAppWindow = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .frame(width: 36, height: 28)
                            .foregroundColor(.white)
                            .background(Color.red.opacity(0.8))
                    }
                }
            }
            .frame(height: 28)
            .background(Color(red: 0.2, green: 0.2, blue: 0.25))
            
            // App content area — live output from Wine/Box64 process
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                
                if processManager.isRunning {
                    // Live process output (scrolling console inside app window)
                    VStack(spacing: 0) {
                        // Status bar
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(processManager.currentProcessName)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("\(processManager.fps) FPS")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.green.opacity(0.8))
                            Text(container.screenResolution)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        
                        // Metal view for actual EXE rendering
                        MetalViewRepresentable(renderer: metalRenderer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                let res = container.screenResolution.split(separator: "x")
                                if res.count == 2 {
                                    let w = Int(res[0]) ?? 1280
                                    let h = Int(res[1]) ?? 720
                                    metalRenderer.createFramebuffer(width: w, height: h)
                                }
                            }
                    }
                } else {
                    // Not running yet
                    VStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Launch an EXE to start")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .cornerRadius(appWindowMaximized ? 0 : 8)
        .shadow(color: .black.opacity(appWindowMaximized ? 0 : 0.5), radius: 10)
        .padding(appWindowMaximized ? 0 : 16)
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
        .padding(.horizontal)
        .padding(.bottom, 8)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.45)
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
            Button(action: { showingConsole.toggle() }) {
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
            
            // Running processes - TAPPABLE to show/hide app window
            if processManager.isRunning {
                Button(action: {
                    showingAppWindow.toggle()
                    if showingAppWindow { appWindowMaximized = true }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "app.fill")
                            .font(.caption2)
                        Text(processManager.currentProcessName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showingAppWindow ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(showingAppWindow ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // System tray
            HStack(spacing: 6) {
                if processManager.isRunning {
                    Text("\(processManager.fps) FPS")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
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
        showingAppWindow = true
        appWindowMaximized = true
        showingConsole = false
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

// MARK: - Metal View Bridge

struct MetalViewRepresentable: UIViewRepresentable {
    let renderer: MetalRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = renderer
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        
        // Set device
        mtkView.device = renderer.getDevice()
        
        // Configure for framebuffer rendering
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        
        print("[MetalView] Created with device: \(mtkView.device?.name ?? "unknown")")
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update view if needed
    }
}
