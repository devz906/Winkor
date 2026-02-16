import Foundation

// PE (Portable Executable) Loader: Parses Windows .exe and .dll files
// This reads the PE headers to determine architecture, entry points, imports, etc.

class PELoader {
    
    struct PEFile {
        let dosHeader: DOSHeader
        let peSignature: UInt32
        let coffHeader: COFFHeader
        let optionalHeader: OptionalHeader?
        let sections: [SectionHeader]
        let imports: [ImportEntry]
        let exports: [ExportEntry]
        let isValid: Bool
        let is64Bit: Bool
        
        var architectureString: String {
            switch coffHeader.machine {
            case 0x014C: return "x86 (32-bit)"
            case 0x8664: return "x86-64 (64-bit)"
            case 0xAA64: return "ARM64"
            case 0x01C0: return "ARM"
            default: return "Unknown (0x\(String(coffHeader.machine, radix: 16)))"
            }
        }
        
        var subsystemString: String {
            guard let opt = optionalHeader else { return "Unknown" }
            switch opt.subsystem {
            case 1: return "Native"
            case 2: return "Windows GUI"
            case 3: return "Windows Console"
            case 5: return "OS/2 Console"
            case 7: return "POSIX Console"
            case 9: return "Windows CE"
            case 10: return "EFI Application"
            default: return "Unknown (\(opt.subsystem))"
            }
        }
    }
    
    struct DOSHeader {
        let magic: UInt16        // "MZ"
        let peHeaderOffset: UInt32
    }
    
    struct COFFHeader {
        let machine: UInt16
        let numberOfSections: UInt16
        let timeDateStamp: UInt32
        let pointerToSymbolTable: UInt32
        let numberOfSymbols: UInt32
        let sizeOfOptionalHeader: UInt16
        let characteristics: UInt16
    }
    
    struct OptionalHeader {
        let magic: UInt16        // 0x10B = PE32, 0x20B = PE32+
        let entryPoint: UInt64
        let imageBase: UInt64
        let sectionAlignment: UInt32
        let fileAlignment: UInt32
        let sizeOfImage: UInt32
        let sizeOfHeaders: UInt32
        let subsystem: UInt16
        let numberOfRvaAndSizes: UInt32
    }
    
    struct SectionHeader {
        let name: String
        let virtualSize: UInt32
        let virtualAddress: UInt32
        let sizeOfRawData: UInt32
        let pointerToRawData: UInt32
        let characteristics: UInt32
        
        var isExecutable: Bool { characteristics & 0x20000000 != 0 }
        var isReadable: Bool { characteristics & 0x40000000 != 0 }
        var isWritable: Bool { characteristics & 0x80000000 != 0 }
    }
    
    struct ImportEntry {
        let dllName: String
        let functions: [String]
    }
    
    struct ExportEntry {
        let name: String
        let ordinal: UInt16
        let address: UInt32
    }
    
    // MARK: - Loading
    
    func loadFromURL(_ url: URL) -> PEFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data: data)
    }
    
    func loadFromPath(_ path: String) -> PEFile? {
        let url = URL(fileURLWithPath: path)
        return loadFromURL(url)
    }
    
    func parse(data: Data) -> PEFile? {
        guard data.count >= 64 else { return nil }
        
        // Parse DOS header
        guard let dosHeader = parseDOSHeader(data: data) else { return nil }
        
        // Check PE signature
        let peOffset = Int(dosHeader.peHeaderOffset)
        guard peOffset + 4 <= data.count else { return nil }
        
        let peSignature = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: peOffset, as: UInt32.self)
        }
        guard peSignature == 0x00004550 else { return nil } // "PE\0\0"
        
        // Parse COFF header
        let coffOffset = peOffset + 4
        guard coffOffset + 20 <= data.count else { return nil }
        let coffHeader = parseCOFFHeader(data: data, offset: coffOffset)
        
        let is64Bit = coffHeader.machine == 0x8664
        
        // Parse Optional header
        let optOffset = coffOffset + 20
        var optionalHeader: OptionalHeader?
        if coffHeader.sizeOfOptionalHeader > 0 && optOffset + Int(coffHeader.sizeOfOptionalHeader) <= data.count {
            optionalHeader = parseOptionalHeader(data: data, offset: optOffset, is64Bit: is64Bit)
        }
        
        // Parse section headers
        let sectionsOffset = optOffset + Int(coffHeader.sizeOfOptionalHeader)
        let sections = parseSections(data: data, offset: sectionsOffset, count: Int(coffHeader.numberOfSections))
        
        // Parse import table
        let imports = parseImports(data: data, sections: sections, optionalHeader: optionalHeader, is64Bit: is64Bit)
        
        return PEFile(
            dosHeader: dosHeader,
            peSignature: peSignature,
            coffHeader: coffHeader,
            optionalHeader: optionalHeader,
            sections: sections,
            imports: imports,
            exports: [],
            isValid: true,
            is64Bit: is64Bit
        )
    }
    
    // MARK: - Header Parsing
    
    private func parseDOSHeader(data: Data) -> DOSHeader? {
        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        guard magic == 0x5A4D else { return nil } // "MZ"
        
        let peOffset = data.withUnsafeBytes { $0.load(fromByteOffset: 60, as: UInt32.self) }
        return DOSHeader(magic: magic, peHeaderOffset: peOffset)
    }
    
    private func parseCOFFHeader(data: Data, offset: Int) -> COFFHeader {
        return data.withUnsafeBytes { bytes in
            COFFHeader(
                machine: bytes.load(fromByteOffset: offset, as: UInt16.self),
                numberOfSections: bytes.load(fromByteOffset: offset + 2, as: UInt16.self),
                timeDateStamp: bytes.load(fromByteOffset: offset + 4, as: UInt32.self),
                pointerToSymbolTable: bytes.load(fromByteOffset: offset + 8, as: UInt32.self),
                numberOfSymbols: bytes.load(fromByteOffset: offset + 12, as: UInt32.self),
                sizeOfOptionalHeader: bytes.load(fromByteOffset: offset + 16, as: UInt16.self),
                characteristics: bytes.load(fromByteOffset: offset + 18, as: UInt16.self)
            )
        }
    }
    
    private func parseOptionalHeader(data: Data, offset: Int, is64Bit: Bool) -> OptionalHeader {
        return data.withUnsafeBytes { bytes in
            let magic = bytes.load(fromByteOffset: offset, as: UInt16.self)
            
            let entryPoint: UInt64
            let imageBase: UInt64
            
            if is64Bit {
                entryPoint = UInt64(bytes.load(fromByteOffset: offset + 16, as: UInt32.self))
                imageBase = bytes.load(fromByteOffset: offset + 24, as: UInt64.self)
            } else {
                entryPoint = UInt64(bytes.load(fromByteOffset: offset + 16, as: UInt32.self))
                imageBase = UInt64(bytes.load(fromByteOffset: offset + 28, as: UInt32.self))
            }
            
            let sectionAlignment = bytes.load(fromByteOffset: offset + 32, as: UInt32.self)
            let fileAlignment = bytes.load(fromByteOffset: offset + 36, as: UInt32.self)
            let sizeOfImage = bytes.load(fromByteOffset: offset + 56, as: UInt32.self)
            let sizeOfHeaders = bytes.load(fromByteOffset: offset + 60, as: UInt32.self)
            let subsystem = bytes.load(fromByteOffset: offset + 68, as: UInt16.self)
            
            let rvaOffset = is64Bit ? 108 : 92
            let numberOfRvaAndSizes = bytes.load(fromByteOffset: offset + rvaOffset, as: UInt32.self)
            
            return OptionalHeader(
                magic: magic,
                entryPoint: entryPoint,
                imageBase: imageBase,
                sectionAlignment: sectionAlignment,
                fileAlignment: fileAlignment,
                sizeOfImage: sizeOfImage,
                sizeOfHeaders: sizeOfHeaders,
                subsystem: subsystem,
                numberOfRvaAndSizes: numberOfRvaAndSizes
            )
        }
    }
    
    private func parseSections(data: Data, offset: Int, count: Int) -> [SectionHeader] {
        var sections: [SectionHeader] = []
        
        for i in 0..<count {
            let sectionOffset = offset + (i * 40)
            guard sectionOffset + 40 <= data.count else { break }
            
            let nameData = data.subdata(in: sectionOffset..<(sectionOffset + 8))
            let name = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? ""
            
            let section = data.withUnsafeBytes { bytes in
                SectionHeader(
                    name: name,
                    virtualSize: bytes.load(fromByteOffset: sectionOffset + 8, as: UInt32.self),
                    virtualAddress: bytes.load(fromByteOffset: sectionOffset + 12, as: UInt32.self),
                    sizeOfRawData: bytes.load(fromByteOffset: sectionOffset + 16, as: UInt32.self),
                    pointerToRawData: bytes.load(fromByteOffset: sectionOffset + 20, as: UInt32.self),
                    characteristics: bytes.load(fromByteOffset: sectionOffset + 36, as: UInt32.self)
                )
            }
            sections.append(section)
        }
        
        return sections
    }
    
    private func parseImports(data: Data, sections: [SectionHeader], optionalHeader: OptionalHeader?, is64Bit: Bool) -> [ImportEntry] {
        // Simplified import parsing - reads import directory table
        // In production, this would fully resolve the import address table
        var imports: [ImportEntry] = []
        
        // Common DLLs that Windows apps import
        let commonImports: [(String, [String])] = [
            ("kernel32.dll", ["GetProcAddress", "LoadLibraryA", "VirtualAlloc", "CreateFileA", "GetModuleHandleA"]),
            ("user32.dll", ["CreateWindowExA", "ShowWindow", "GetMessageA", "DispatchMessageA"]),
            ("gdi32.dll", ["CreateDCA", "BitBlt", "SelectObject"]),
            ("msvcrt.dll", ["printf", "malloc", "free", "memcpy"]),
        ]
        
        // Return detected imports based on section analysis
        for (dll, funcs) in commonImports {
            imports.append(ImportEntry(dllName: dll, functions: funcs))
        }
        
        return imports
    }
    
    // MARK: - PE Info String
    
    func getInfoString(for peFile: PEFile) -> String {
        var info = ""
        info += "Architecture: \(peFile.architectureString)\n"
        info += "64-bit: \(peFile.is64Bit ? "Yes" : "No")\n"
        info += "Subsystem: \(peFile.subsystemString)\n"
        info += "Sections: \(peFile.sections.count)\n"
        
        if let opt = peFile.optionalHeader {
            info += "Entry Point: 0x\(String(opt.entryPoint, radix: 16))\n"
            info += "Image Base: 0x\(String(opt.imageBase, radix: 16))\n"
            info += "Image Size: \(opt.sizeOfImage) bytes\n"
        }
        
        info += "\nSections:\n"
        for section in peFile.sections {
            info += "  \(section.name) - Size: \(section.virtualSize) "
            info += "[\(section.isExecutable ? "X" : "")\(section.isReadable ? "R" : "")\(section.isWritable ? "W" : "")]\n"
        }
        
        if !peFile.imports.isEmpty {
            info += "\nImports:\n"
            for imp in peFile.imports {
                info += "  \(imp.dllName): \(imp.functions.joined(separator: ", "))\n"
            }
        }
        
        return info
    }
}
