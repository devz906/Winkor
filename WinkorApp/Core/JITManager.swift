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
        // Test 1: Try MAP_JIT with RW, then toggle to RX using pthread_jit_write_protect_np
        // This is the modern iOS way (iOS 14+)
        let pageSize = Int(getpagesize())
        
        let jitPtr = mmap(
            nil,
            pageSize,
            PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANON | MAP_JIT,
            -1,
            0
        )
        
        if jitPtr != MAP_FAILED {
            // MAP_JIT succeeded — JIT is available
            // Try writing a NOP instruction and executing
            pthread_jit_write_protect_np(false)
            jitPtr!.storeBytes(of: UInt32(0xD65F03C0), as: UInt32.self) // ARM64 RET
            pthread_jit_write_protect_np(true)
            sys_icache_invalidate(jitPtr!, pageSize)
            munmap(jitPtr, pageSize)
            return true
        }
        
        // Test 2: Try RWX directly (older method, works with debugger-attached JIT)
        let rwxPtr = mmap(
            nil,
            pageSize,
            PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANON,
            -1,
            0
        )
        
        if rwxPtr != MAP_FAILED {
            munmap(rwxPtr, pageSize)
            return true
        }
        
        // Test 3: RW then mprotect to RX
        let rwPtr = mmap(
            nil,
            pageSize,
            PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANON,
            -1,
            0
        )
        
        if rwPtr != MAP_FAILED {
            let result = mprotect(rwPtr, pageSize, PROT_READ | PROT_EXEC)
            munmap(rwPtr, pageSize)
            if result == 0 {
                return true
            }
        }
        
        return false
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.checkEntitlement(completion: completion)
            }
        case .altJIT:
            enableViaAltJIT(completion: completion)
        }
    }
    
    private func enableViaSideJITServer(completion: @escaping (Bool, String) -> Void) {
        // Run entirely off the main thread to avoid UI freeze
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let hosts = ["192.168.1.1", "192.168.0.1", "10.0.0.1",
                         "192.168.1.100", "192.168.0.100", "172.16.0.1"]
            
            let group = DispatchGroup()
            var foundHost: String?
            let lock = NSLock()
            
            for host in hosts {
                guard let url = URL(string: "http://\(host):8080/status") else { continue }
                group.enter()
                var request = URLRequest(url: url, timeoutInterval: 2)
                request.httpMethod = "GET"
                
                URLSession.shared.dataTask(with: request) { _, response, _ in
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        lock.lock()
                        if foundHost == nil { foundHost = host }
                        lock.unlock()
                    }
                    group.leave()
                }.resume()
            }
            
            group.wait()
            
            if let host = foundHost {
                let bundleID = Bundle.main.bundleIdentifier ?? "com.winkor.emulator"
                guard let enableURL = URL(string: "http://\(host):8080/enable-jit/\(bundleID)") else {
                    DispatchQueue.main.async { completion(false, "Invalid SideJITServer URL") }
                    return
                }
                
                URLSession.shared.dataTask(with: enableURL) { [weak self] _, response, _ in
                    DispatchQueue.main.async {
                        if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                            self?.isJITEnabled = true
                            self?.status = .enabled
                            completion(true, "JIT enabled via SideJITServer at \(host)")
                        } else {
                            completion(false, "SideJITServer found at \(host) but JIT enable failed")
                        }
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    completion(false, "SideJITServer not found on local network. Make sure it's running on your PC and both devices are on the same WiFi.")
                }
            }
        }
    }
    
    private func enableViaJITStreamer(completion: @escaping (Bool, String) -> Void) {
        // Re-check JIT after user may have used the shortcut
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let available = self?.testJITCapability() ?? false
            DispatchQueue.main.async {
                if available {
                    self?.isJITEnabled = true
                    self?.status = .enabled
                    completion(true, "JIT is now enabled!")
                } else {
                    completion(false, "JIT not yet enabled. Run the JITStreamer shortcut first, then tap this again.")
                }
            }
        }
    }
    
    private func enableViaDebugger(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let available = self?.testJITCapability() ?? false
            DispatchQueue.main.async {
                if available {
                    self?.isJITEnabled = true
                    self?.status = .enabled
                    completion(true, "JIT detected via debugger!")
                } else {
                    completion(false, "No debugger attached. Connect to Xcode and run the app from there.")
                }
            }
        }
    }
    
    private func checkEntitlement(completion: @escaping (Bool, String) -> Void) {
        let jitTest = testJITCapability()
        DispatchQueue.main.async { [weak self] in
            if jitTest {
                self?.isJITEnabled = true
                self?.status = .enabled
                completion(true, "JIT available via entitlement")
            } else {
                completion(false, "dynamic-codesigning entitlement not present. Requires jailbreak.")
            }
        }
    }
    
    private func enableViaAltJIT(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let available = self?.testJITCapability() ?? false
            DispatchQueue.main.async {
                if available {
                    self?.isJITEnabled = true
                    self?.status = .enabled
                    completion(true, "JIT is now enabled via AltJIT!")
                } else {
                    completion(false, "JIT not enabled yet. Enable JIT from AltStore/SideStore first, then tap again.")
                }
            }
        }
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
