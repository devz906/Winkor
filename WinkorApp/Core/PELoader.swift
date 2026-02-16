import Foundation
import UIKit

class PELoader {
    static let shared = PELoader()
    
    struct PEInfo {
        let isExecutable: Bool
        let architecture: String
        let entryPoint: UInt32
        let imageSize: UInt32
        let subsystem: UInt16
    }
    
    func analyzePEFile(atPath path: String) -> PEInfo? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("❌ Failed to read PE file")
            return nil
        }
        
        // Check DOS header
        if data.count < 64 {
            print("❌ File too small for PE header")
            return nil
        }
        
        // Check MZ signature
        let mzSignature = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        if mzSignature != 0x5A4D { // "MZ"
            print("❌ Invalid DOS signature")
            return nil
        }
        
        // Get PE header offset
        let peOffset = data.withUnsafeBytes { $0.load(fromByteOffset: 60, as: UInt32.self) }
        if peOffset + 4 > data.count {
            print("❌ Invalid PE offset")
            return nil
        }
        
        // Check PE signature
        let peSignature = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset), as: UInt32.self) }
        if peSignature != 0x00004550 { // "PE\0\0"
            print("❌ Invalid PE signature")
            return nil
        }
        
        // Read COFF header
        let machine = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 4), as: UInt16.self) }
        let numberOfSections = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 6), as: UInt16.self) }
        let timestamp = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 8), as: UInt32.self) }
        let symbolTablePtr = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 12), as: UInt32.self) }
        let numberOfSymbols = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 16), as: UInt32.self) }
        let optionalHeaderSize = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 20), as: UInt16.self) }
        let characteristics = data.withUnsafeBytes { $0.load(fromByteOffset: Int(peOffset + 22), as: UInt16.self) }
        
        // Read optional header
        let optionalHeaderOffset = Int(peOffset + 24)
        if optionalHeaderOffset + optionalHeaderSize > data.count {
            print("❌ Invalid optional header")
            return nil
        }
        
        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: optionalHeaderOffset, as: UInt16.self) }
        let entryPoint = data.withUnsafeBytes { $0.load(fromByteOffset: optionalHeaderOffset + 16, as: UInt32.self) }
        let imageSize = data.withUnsafeBytes { $0.load(fromByteOffset: optionalHeaderOffset + 20, as: UInt32.self) }
        let subsystem = data.withUnsafeBytes { $0.load(fromByteOffset: optionalHeaderOffset + 68, as: UInt16.self) }
        
        // Determine architecture
        let archString: String
        switch machine {
        case 0x014c:
            archString = "x86"
        case 0x8664:
            archString = "x86-64"
        case 0x01c0:
            archString = "ARM"
        case 0xaa64:
            archString = "ARM64"
        default:
            archString = "Unknown (0x\(String(machine, radix: 16)))"
        }
        
        // Check if executable
        let isExecutable = (characteristics & 0x2000) != 0 // IMAGE_FILE_EXECUTABLE_IMAGE
        
        print("✅ PE Analysis:")
        print("   Architecture: \(archString)")
        print("   Entry Point: 0x\(String(entryPoint, radix: 16))")
        print("   Image Size: \(imageSize) bytes")
        print("   Subsystem: \(subsystem)")
        print("   Executable: \(isExecutable)")
        
        return PEInfo(
            isExecutable: isExecutable,
            architecture: archString,
            entryPoint: entryPoint,
            imageSize: imageSize,
            subsystem: subsystem
        )
    }
    
    func canExecuteOniOS(_ peInfo: PEInfo) -> Bool {
        // For now, we'll accept x86 and x86-64 (will need emulation)
        return peInfo.isExecutable && (peInfo.architecture == "x86" || peInfo.architecture == "x86-64")
    }
}
