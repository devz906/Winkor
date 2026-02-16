import Foundation
import MachO

// JIT Manager: Handles JIT (Just-In-Time) compilation permissions on iOS
// JIT is REQUIRED for Box64 dynarec to work - without it, everything runs in interpreter mode (very slow)
// Methods to enable JIT:
//   1. SideJITServer (recommended) - companion app on PC enables JIT over network
//   2. JIT via debugger attach
//   3. AltJIT / JITStreamer
//   4. Direct entitlement (jailbroken devices)

class JITManager: ObservableObject {
    
    enum JITStatus: String {
        case enabled = "JIT Enabled"
        case disabled = "JIT Disabled"
        case checking = "Checking JIT..."
        case unknown = "Unknown"
    }
    
    enum JITMethod: String, CaseIterable {
        case sideJITServer = "SideJITServer"
        case jitStreamer = "JITStreamer"
        case debuggerAttach = "Debugger Attach"
        case entitlement = "Entitlement (Jailbreak)"
        case altJIT = "AltJIT"
    }
    
    @Published var status: JITStatus = .unknown
    @Published var isJITEnabled: Bool = false
    @Published var currentMethod: JITMethod?
    
    init() {
        checkJITStatus()
    }
    
    // MARK: - JIT Detection
    
    func checkJITStatus() {
        status = .checking
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let jitAvailable = self?.testJITCapability() ?? false
            
            DispatchQueue.main.async {
                self?.isJITEnabled = jitAvailable
                self?.status = jitAvailable ? .enabled : .disabled
                
                if jitAvailable {
                    print("[JITManager] JIT is ENABLED - Box64 dynarec will work at full speed")
                } else {
                    print("[JITManager] JIT is DISABLED - Box64 will use interpreter mode (slow)")
                    print("[JITManager] Use SideJITServer or similar to enable JIT")
                }
            }
        }
    }
    
    private func testJITCapability() -> Bool {
        // Test if we can allocate and execute memory with RWX permissions
        // This is the definitive test for JIT capability on iOS
        
        let pageSize = Int(getpagesize())
        
        // Try to allocate RWX memory
        let ptr = mmap(
            nil,
            pageSize,
            PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT,
            -1,
            0
        )
        
        if ptr == MAP_FAILED {
            // RWX allocation failed - try RW then toggle to RX
            let rwPtr = mmap(
                nil,
                pageSize,
                PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT,
                -1,
                0
            )
            
            if rwPtr == MAP_FAILED {
                return false
            }
            
            // Try to make it executable
            let result = mprotect(rwPtr, pageSize, PROT_READ | PROT_EXEC)
            munmap(rwPtr, pageSize)
            return result == 0
        }
        
        munmap(ptr, pageSize)
        return true
    }
    
    // MARK: - JIT Enable Methods
    
    func enableJIT(method: JITMethod, completion: @escaping (Bool, String) -> Void) {
        currentMethod = method
        
        switch method {
        case .sideJITServer:
            enableViaSideJITServer(completion: completion)
        case .jitStreamer:
            enableViaJITStreamer(completion: completion)
        case .debuggerAttach:
            enableViaDebugger(completion: completion)
        case .entitlement:
            checkEntitlement(completion: completion)
        case .altJIT:
            enableViaAltJIT(completion: completion)
        }
    }
    
    private func enableViaSideJITServer(completion: @escaping (Bool, String) -> Void) {
        // SideJITServer works by:
        // 1. Running a companion app on a PC on the same network
        // 2. The companion attaches a debugger to the iOS app
        // 3. This grants JIT permissions
        // 4. The debugger detaches, leaving JIT enabled
        
        // Check if SideJITServer is reachable on local network
        // Default port: 8080
        
        let hosts = ["192.168.1.1", "192.168.0.1", "10.0.0.1"]
        
        for host in hosts {
            if let url = URL(string: "http://\(host):8080/status") {
                var request = URLRequest(url: url, timeoutInterval: 2)
                request.httpMethod = "GET"
                
                let semaphore = DispatchSemaphore(value: 0)
                var found = false
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        found = true
                    }
                    semaphore.signal()
                }.resume()
                
                semaphore.wait()
                
                if found {
                    // Request JIT enable
                    let bundleID = Bundle.main.bundleIdentifier ?? "com.winkor.emulator"
                    if let enableURL = URL(string: "http://\(host):8080/enable-jit/\(bundleID)") {
                        URLSession.shared.dataTask(with: enableURL) { [weak self] _, response, error in
                            DispatchQueue.main.async {
                                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                                    self?.isJITEnabled = true
                                    self?.status = .enabled
                                    completion(true, "JIT enabled via SideJITServer at \(host)")
                                } else {
                                    completion(false, "SideJITServer found but JIT enable failed")
                                }
                            }
                        }.resume()
                        return
                    }
                }
            }
        }
        
        completion(false, "SideJITServer not found on local network. Make sure it's running on your PC.")
    }
    
    private func enableViaJITStreamer(completion: @escaping (Bool, String) -> Void) {
        completion(false, "JITStreamer requires the JITStreamer shortcut. Install it from the JITStreamer GitHub page.")
    }
    
    private func enableViaDebugger(completion: @escaping (Bool, String) -> Void) {
        completion(false, "Connect your device to Xcode and run the app from there to get debugger-attached JIT.")
    }
    
    private func checkEntitlement(completion: @escaping (Bool, String) -> Void) {
        // Check if dynamic-codesigning entitlement is present (jailbreak)
        let jitTest = testJITCapability()
        if jitTest {
            isJITEnabled = true
            status = .enabled
            completion(true, "JIT available via entitlement")
        } else {
            completion(false, "dynamic-codesigning entitlement not present. Requires jailbreak.")
        }
    }
    
    private func enableViaAltJIT(completion: @escaping (Bool, String) -> Void) {
        completion(false, "AltJIT requires AltStore with JIT support. Enable JIT from AltStore app.")
    }
    
    // MARK: - Memory Management for JIT
    
    func getAvailableRAM() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return ProcessInfo.processInfo.physicalMemory - info.resident_size
        }
        return ProcessInfo.processInfo.physicalMemory
    }
    
    func getTotalRAM() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    func getRAMString() -> String {
        let total = getTotalRAM()
        let available = getAvailableRAM()
        let totalGB = Double(total) / 1_073_741_824
        let availGB = Double(available) / 1_073_741_824
        return String(format: "%.1f GB / %.1f GB", availGB, totalGB)
    }
}
