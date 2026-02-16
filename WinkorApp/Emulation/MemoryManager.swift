import Foundation

// Virtual Memory Manager for x86-64 address space emulation
// Maps the Windows virtual memory layout within the iOS process

class VirtualMemoryManager {
    
    struct MemoryRegion {
        let baseAddress: UInt64
        let size: UInt64
        let name: String
        let protection: MemoryProtection
        var isAllocated: Bool
    }
    
    struct MemoryProtection: OptionSet {
        let rawValue: UInt32
        static let read     = MemoryProtection(rawValue: 1 << 0)
        static let write    = MemoryProtection(rawValue: 1 << 1)
        static let execute  = MemoryProtection(rawValue: 1 << 2)
        static let noAccess = MemoryProtection(rawValue: 0)
        static let readWrite: MemoryProtection = [.read, .write]
        static let readExecute: MemoryProtection = [.read, .execute]
        static let readWriteExecute: MemoryProtection = [.read, .write, .execute]
    }
    
    // Windows memory layout (simplified)
    // 0x00000000 - 0x0000FFFF: Null page (reserved)
    // 0x00010000 - 0x7FFEFFFF: User space
    // 0x00400000 - default EXE image base
    // 0x10000000 - default DLL load area
    // 0x7FFE0000 - SharedUserData
    // 0x7FFF0000 - 0x7FFFFFFF: Reserved
    // Stack grows down from high addresses
    
    private var regions: [MemoryRegion] = []
    private var pageTable: [UInt64: UnsafeMutableRawPointer] = [:]
    private let pageSize: UInt64 = 4096
    private var totalAllocated: UInt64 = 0
    private let maxMemory: UInt64 // Maximum memory for this container
    
    init(maxMemoryMB: Int) {
        self.maxMemory = UInt64(maxMemoryMB) * 1024 * 1024
        setupDefaultRegions()
    }
    
    deinit {
        // Free all allocated pages
        for (_, ptr) in pageTable {
            ptr.deallocate()
        }
        pageTable.removeAll()
    }
    
    private func setupDefaultRegions() {
        // Reserve null page
        regions.append(MemoryRegion(
            baseAddress: 0x0,
            size: 0x10000,
            name: "Null Page",
            protection: .noAccess,
            isAllocated: true
        ))
        
        // Default EXE image space
        regions.append(MemoryRegion(
            baseAddress: 0x400000,
            size: 0x10000000,
            name: "EXE Image",
            protection: .readExecute,
            isAllocated: false
        ))
        
        // DLL loading area
        regions.append(MemoryRegion(
            baseAddress: 0x10000000,
            size: 0x60000000,
            name: "DLL Space",
            protection: .readExecute,
            isAllocated: false
        ))
        
        // Heap area
        regions.append(MemoryRegion(
            baseAddress: 0x80000000,
            size: 0x40000000,
            name: "Heap",
            protection: .readWrite,
            isAllocated: false
        ))
        
        // Stack
        regions.append(MemoryRegion(
            baseAddress: 0x7FF00000,
            size: 0x100000, // 1MB default stack
            name: "Main Stack",
            protection: .readWrite,
            isAllocated: false
        ))
    }
    
    // MARK: - Windows VirtualAlloc equivalent
    
    func virtualAlloc(address: UInt64?, size: UInt64, protection: MemoryProtection) -> UInt64? {
        let alignedSize = (size + pageSize - 1) & ~(pageSize - 1)
        
        guard totalAllocated + alignedSize <= maxMemory else {
            print("[Memory] Allocation failed: out of memory (\(totalAllocated)/\(maxMemory))")
            return nil
        }
        
        let baseAddr: UInt64
        if let requestedAddr = address {
            baseAddr = requestedAddr & ~(pageSize - 1) // Align to page
        } else {
            // Find free space in heap region
            baseAddr = findFreeSpace(size: alignedSize) ?? 0x80000000
        }
        
        // Allocate pages
        let pageCount = Int(alignedSize / pageSize)
        for i in 0..<pageCount {
            let pageAddr = baseAddr + UInt64(i) * pageSize
            if pageTable[pageAddr] == nil {
                let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(pageSize), alignment: Int(pageSize))
                ptr.initializeMemory(as: UInt8.self, repeating: 0, count: Int(pageSize))
                pageTable[pageAddr] = ptr
            }
        }
        
        totalAllocated += alignedSize
        
        regions.append(MemoryRegion(
            baseAddress: baseAddr,
            size: alignedSize,
            name: "User Allocation",
            protection: protection,
            isAllocated: true
        ))
        
        return baseAddr
    }
    
    func virtualFree(address: UInt64, size: UInt64) {
        let alignedSize = (size + pageSize - 1) & ~(pageSize - 1)
        let pageCount = Int(alignedSize / pageSize)
        
        for i in 0..<pageCount {
            let pageAddr = address + UInt64(i) * pageSize
            if let ptr = pageTable[pageAddr] {
                ptr.deallocate()
                pageTable.removeValue(forKey: pageAddr)
            }
        }
        
        totalAllocated -= min(alignedSize, totalAllocated)
        regions.removeAll { $0.baseAddress == address && $0.name == "User Allocation" }
    }
    
    // MARK: - Read/Write
    
    func readByte(at address: UInt64) -> UInt8 {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return 0 }
        return ptr.load(fromByteOffset: offset, as: UInt8.self)
    }
    
    func readUInt32(at address: UInt64) -> UInt32 {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return 0 }
        return ptr.load(fromByteOffset: offset, as: UInt32.self)
    }
    
    func readUInt64(at address: UInt64) -> UInt64 {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return 0 }
        return ptr.load(fromByteOffset: offset, as: UInt64.self)
    }
    
    func writeByte(_ value: UInt8, at address: UInt64) {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return }
        ptr.storeBytes(of: value, toByteOffset: offset, as: UInt8.self)
    }
    
    func writeUInt32(_ value: UInt32, at address: UInt64) {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return }
        ptr.storeBytes(of: value, toByteOffset: offset, as: UInt32.self)
    }
    
    func writeUInt64(_ value: UInt64, at address: UInt64) {
        let pageAddr = address & ~(pageSize - 1)
        let offset = Int(address & (pageSize - 1))
        guard let ptr = pageTable[pageAddr] else { return }
        ptr.storeBytes(of: value, toByteOffset: offset, as: UInt64.self)
    }
    
    func writeData(_ data: Data, at address: UInt64) {
        for (i, byte) in data.enumerated() {
            writeByte(byte, at: address + UInt64(i))
        }
    }
    
    func readData(at address: UInt64, count: Int) -> Data {
        var bytes = [UInt8]()
        for i in 0..<count {
            bytes.append(readByte(at: address + UInt64(i)))
        }
        return Data(bytes)
    }
    
    // MARK: - Helpers
    
    private func findFreeSpace(size: UInt64) -> UInt64? {
        // Simple first-fit allocation in heap region
        var candidate: UInt64 = 0x80000000
        let heapEnd: UInt64 = 0xC0000000
        
        while candidate + size <= heapEnd {
            var overlaps = false
            for region in regions where region.isAllocated {
                let regionEnd = region.baseAddress + region.size
                if candidate < regionEnd && candidate + size > region.baseAddress {
                    candidate = regionEnd
                    overlaps = true
                    break
                }
            }
            if !overlaps {
                return candidate
            }
        }
        return nil
    }
    
    func getMemoryStats() -> (allocated: UInt64, max: UInt64, regions: Int) {
        return (totalAllocated, maxMemory, regions.count)
    }
    
    func getRegions() -> [MemoryRegion] {
        return regions
    }
}
