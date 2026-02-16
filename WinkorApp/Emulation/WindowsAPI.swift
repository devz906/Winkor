import Foundation

// Windows API Implementation: Stubs and translations for core Win32 APIs
// These are used when Wine needs to call Windows system functions
// Wine handles most of this, but we need iOS-side implementations for some calls

class WindowsAPIBridge {
    
    // Windows API function signature
    typealias WinAPIHandler = ([UInt64]) -> UInt64
    
    private var apiTable: [String: [String: WinAPIHandler]] = [:]
    private let memory: VirtualMemoryManager
    
    init(memory: VirtualMemoryManager) {
        self.memory = memory
        registerAllAPIs()
    }
    
    private func registerAllAPIs() {
        registerKernel32()
        registerUser32()
        registerGDI32()
        registerAdvapi32()
        registerShell32()
        registerWS2_32()
        registerWinMM()
        registerOle32()
    }
    
    func callAPI(dll: String, function: String, params: [UInt64]) -> UInt64 {
        let dllLower = dll.lowercased()
        if let dllTable = apiTable[dllLower], let handler = dllTable[function] {
            return handler(params)
        }
        print("[WinAPI] Unimplemented: \(dll)!\(function)")
        return 0
    }
    
    // MARK: - Kernel32
    
    private func registerKernel32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["GetProcAddress"] = { params in
            // Returns fake function pointer
            return 0x12345678
        }
        
        table["LoadLibraryA"] = { params in
            return 0x10000000 // Fake module handle
        }
        
        table["LoadLibraryW"] = { params in
            return 0x10000000
        }
        
        table["GetModuleHandleA"] = { params in
            return 0x00400000 // Default image base
        }
        
        table["GetModuleHandleW"] = { params in
            return 0x00400000
        }
        
        table["GetCurrentProcess"] = { _ in
            return 0xFFFFFFFFFFFFFFFF // Pseudo-handle
        }
        
        table["GetCurrentProcessId"] = { _ in
            return UInt64(ProcessInfo.processInfo.processIdentifier)
        }
        
        table["GetCurrentThreadId"] = { _ in
            return 1
        }
        
        table["GetTickCount"] = { _ in
            return UInt64(ProcessInfo.processInfo.systemUptime * 1000)
        }
        
        table["GetTickCount64"] = { _ in
            return UInt64(ProcessInfo.processInfo.systemUptime * 1000)
        }
        
        table["QueryPerformanceCounter"] = { [weak self] params in
            guard let self = self else { return 0 }
            let time = UInt64(mach_absolute_time())
            if params.count > 0 {
                self.memory.writeUInt64(time, at: params[0])
            }
            return 1
        }
        
        table["QueryPerformanceFrequency"] = { [weak self] params in
            guard let self = self else { return 0 }
            var info = mach_timebase_info_data_t()
            mach_timebase_info(&info)
            let freq = UInt64(info.denom) * 1_000_000_000 / UInt64(info.numer)
            if params.count > 0 {
                self.memory.writeUInt64(freq, at: params[0])
            }
            return 1
        }
        
        table["Sleep"] = { params in
            if params.count > 0 {
                Thread.sleep(forTimeInterval: Double(params[0]) / 1000.0)
            }
            return 0
        }
        
        table["VirtualAlloc"] = { [weak self] params in
            guard let self = self else { return 0 }
            let addr = params.count > 0 ? params[0] : 0
            let size = params.count > 1 ? params[1] : 4096
            let result = self.memory.virtualAlloc(
                address: addr == 0 ? nil : addr,
                size: size,
                protection: .readWrite
            )
            return result ?? 0
        }
        
        table["VirtualFree"] = { [weak self] params in
            guard let self = self else { return 0 }
            if params.count >= 2 {
                self.memory.virtualFree(address: params[0], size: params[1])
            }
            return 1
        }
        
        table["GetSystemInfo"] = { _ in
            return 0
        }
        
        table["GetVersionExA"] = { _ in
            return 1 // Success
        }
        
        table["GetVersionExW"] = { _ in
            return 1
        }
        
        table["CreateFileA"] = { _ in
            return 0xFFFFFFFF // INVALID_HANDLE_VALUE (stub)
        }
        
        table["CloseHandle"] = { _ in
            return 1
        }
        
        table["GetLastError"] = { _ in
            return 0 // ERROR_SUCCESS
        }
        
        table["SetLastError"] = { _ in
            return 0
        }
        
        table["GetCommandLineA"] = { _ in
            return 0
        }
        
        table["GetEnvironmentVariableA"] = { _ in
            return 0
        }
        
        table["GetStdHandle"] = { params in
            let handleType = params.count > 0 ? Int32(params[0]) : -11
            switch handleType {
            case -10: return 1 // STD_INPUT_HANDLE
            case -11: return 2 // STD_OUTPUT_HANDLE
            case -12: return 3 // STD_ERROR_HANDLE
            default: return 0
            }
        }
        
        table["HeapAlloc"] = { [weak self] params in
            guard let self = self else { return 0 }
            let size = params.count > 2 ? params[2] : 0
            return self.memory.virtualAlloc(address: nil, size: size, protection: .readWrite) ?? 0
        }
        
        table["HeapFree"] = { [weak self] params in
            guard let self = self else { return 0 }
            if params.count > 2 {
                self.memory.virtualFree(address: params[2], size: 0)
            }
            return 1
        }
        
        table["GetProcessHeap"] = { _ in
            return 0x80000000
        }
        
        table["ExitProcess"] = { params in
            print("[WinAPI] ExitProcess called with code: \(params.first ?? 0)")
            return 0
        }
        
        apiTable["kernel32.dll"] = table
    }
    
    // MARK: - User32
    
    private func registerUser32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["CreateWindowExA"] = { _ in return 0x11111111 }
        table["CreateWindowExW"] = { _ in return 0x11111111 }
        table["ShowWindow"] = { _ in return 1 }
        table["UpdateWindow"] = { _ in return 1 }
        table["DestroyWindow"] = { _ in return 1 }
        table["GetMessageA"] = { _ in return 1 }
        table["GetMessageW"] = { _ in return 1 }
        table["PeekMessageA"] = { _ in return 0 }
        table["PeekMessageW"] = { _ in return 0 }
        table["TranslateMessage"] = { _ in return 1 }
        table["DispatchMessageA"] = { _ in return 0 }
        table["DispatchMessageW"] = { _ in return 0 }
        table["PostQuitMessage"] = { _ in return 0 }
        table["DefWindowProcA"] = { _ in return 0 }
        table["DefWindowProcW"] = { _ in return 0 }
        table["RegisterClassExA"] = { _ in return 1 }
        table["RegisterClassExW"] = { _ in return 1 }
        table["SetWindowTextA"] = { _ in return 1 }
        table["GetWindowTextA"] = { _ in return 0 }
        table["GetClientRect"] = { _ in return 1 }
        table["GetWindowRect"] = { _ in return 1 }
        table["SetCursorPos"] = { _ in return 1 }
        table["GetCursorPos"] = { _ in return 1 }
        table["ShowCursor"] = { _ in return 1 }
        table["MessageBoxA"] = { _ in return 1 } // IDOK
        table["MessageBoxW"] = { _ in return 1 }
        table["GetSystemMetrics"] = { params in
            let index = params.count > 0 ? Int(params[0]) : 0
            switch index {
            case 0: return 1280  // SM_CXSCREEN
            case 1: return 720   // SM_CYSCREEN
            default: return 0
            }
        }
        table["GetDC"] = { _ in return 0x22222222 }
        table["ReleaseDC"] = { _ in return 1 }
        
        apiTable["user32.dll"] = table
    }
    
    // MARK: - GDI32
    
    private func registerGDI32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["CreateDCA"] = { _ in return 0x22222222 }
        table["CreateCompatibleDC"] = { _ in return 0x22222223 }
        table["CreateCompatibleBitmap"] = { _ in return 0x33333333 }
        table["SelectObject"] = { _ in return 0x33333334 }
        table["DeleteObject"] = { _ in return 1 }
        table["DeleteDC"] = { _ in return 1 }
        table["BitBlt"] = { _ in return 1 }
        table["StretchBlt"] = { _ in return 1 }
        table["GetPixel"] = { _ in return 0x00000000 }
        table["SetPixel"] = { _ in return 0x00000000 }
        table["CreatePen"] = { _ in return 0x44444444 }
        table["CreateSolidBrush"] = { _ in return 0x44444445 }
        table["CreateFontA"] = { _ in return 0x55555555 }
        table["GetDeviceCaps"] = { params in
            let index = params.count > 1 ? Int(params[1]) : 0
            switch index {
            case 8: return 1280   // HORZRES
            case 10: return 720   // VERTRES
            case 12: return 96    // LOGPIXELSX
            case 90: return 96    // LOGPIXELSY
            case 24: return 32    // BITSPIXEL
            default: return 0
            }
        }
        table["SetBkMode"] = { _ in return 1 }
        table["SetTextColor"] = { _ in return 0 }
        table["TextOutA"] = { _ in return 1 }
        
        apiTable["gdi32.dll"] = table
    }
    
    // MARK: - Advapi32
    
    private func registerAdvapi32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["RegOpenKeyExA"] = { _ in return 0 }
        table["RegOpenKeyExW"] = { _ in return 0 }
        table["RegCloseKey"] = { _ in return 0 }
        table["RegQueryValueExA"] = { _ in return 0 }
        table["RegQueryValueExW"] = { _ in return 0 }
        table["RegSetValueExA"] = { _ in return 0 }
        table["RegCreateKeyExA"] = { _ in return 0 }
        table["GetUserNameA"] = { _ in return 1 }
        table["GetUserNameW"] = { _ in return 1 }
        table["OpenProcessToken"] = { _ in return 1 }
        
        apiTable["advapi32.dll"] = table
    }
    
    // MARK: - Shell32
    
    private func registerShell32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["ShellExecuteA"] = { _ in return 33 }
        table["ShellExecuteW"] = { _ in return 33 }
        table["SHGetFolderPathA"] = { _ in return 0 }
        table["SHGetFolderPathW"] = { _ in return 0 }
        table["SHGetSpecialFolderPathA"] = { _ in return 1 }
        table["SHFileOperationA"] = { _ in return 0 }
        table["CommandLineToArgvW"] = { _ in return 0 }
        
        apiTable["shell32.dll"] = table
    }
    
    // MARK: - WS2_32 (Winsock)
    
    private func registerWS2_32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["WSAStartup"] = { _ in return 0 }
        table["WSACleanup"] = { _ in return 0 }
        table["socket"] = { _ in return 0xFFFFFFFF }
        table["connect"] = { _ in return 0xFFFFFFFF }
        table["send"] = { _ in return 0 }
        table["recv"] = { _ in return 0 }
        table["closesocket"] = { _ in return 0 }
        
        apiTable["ws2_32.dll"] = table
    }
    
    // MARK: - WinMM (Multimedia)
    
    private func registerWinMM() {
        var table: [String: WinAPIHandler] = [:]
        
        table["timeGetTime"] = { _ in
            return UInt64(ProcessInfo.processInfo.systemUptime * 1000)
        }
        table["timeBeginPeriod"] = { _ in return 0 }
        table["timeEndPeriod"] = { _ in return 0 }
        table["waveOutOpen"] = { _ in return 0 }
        table["waveOutClose"] = { _ in return 0 }
        table["midiOutOpen"] = { _ in return 0 }
        table["joyGetPosEx"] = { _ in return 0 }
        
        apiTable["winmm.dll"] = table
    }
    
    // MARK: - Ole32
    
    private func registerOle32() {
        var table: [String: WinAPIHandler] = [:]
        
        table["CoInitialize"] = { _ in return 0 } // S_OK
        table["CoInitializeEx"] = { _ in return 0 }
        table["CoUninitialize"] = { _ in return 0 }
        table["CoCreateInstance"] = { _ in return 0x80004002 } // E_NOINTERFACE
        
        apiTable["ole32.dll"] = table
    }
    
    // MARK: - API Count
    
    func getRegisteredAPICount() -> (dlls: Int, functions: Int) {
        let dllCount = apiTable.count
        let funcCount = apiTable.values.reduce(0) { $0 + $1.count }
        return (dllCount, funcCount)
    }
}
