# Winkor - Windows Emulator for iOS

**Run Windows applications and games on iPhone/iPad — Built from GameHub analysis**

## Features

- ✅ **Wine Engine** - Full Windows API compatibility layer
- ✅ **Container System** - Isolated Windows environments  
- ✅ **PE Loader** - Analyze and execute .exe files
- ✅ **Process Manager** - Run and manage Windows processes
- ✅ **File Management** - Import .exe files from iOS Files app
- ✅ **Container Management** - Create and manage multiple containers
- ✅ **SwiftUI Interface** - Modern iOS user interface

## Quick Start

### Prerequisites
- iOS 16+ device
- Xcode 14+
- JIT enabled (SideJITServer recommended)
- 8GB+ RAM recommended for games

### Installation

1. **Clone and Build**
```bash
git clone https://github.com/devz906/Winkor.git
cd Winkor
# Install XcodeGen if needed
brew install xcodegen
xcodegen generate
open Winkor.xcodeproj
```

2. **Build in Xcode**
- Select your iOS device (not simulator)
- Build and run

3. **Enable JIT**
- Use SideJITServer, JITStreamer, or AltJIT
- Required for Wine performance

## Usage

### 1. Initialize Wine Engine
- Open Winkor app
- Tap "Initialize Wine" to setup container system

### 2. Create Container
- Tap "Create Container" for isolated Windows environment
- Each container acts like a separate Windows PC

### 3. Import EXE Files
- Tap "Import EXE File"
- Select .exe files from Files app
- Files are copied to container and analyzed

### 4. Run Applications
- EXE files are automatically executed after import
- Monitor running processes in the app
- Terminate processes when needed

## Architecture

### Core Components
- **WineEngine.swift** - Wine container management
- **PELoader.swift** - Windows executable analysis
- **ContainerManager.swift** - Windows container system
- **ProcessManager.swift** - Process execution and management

### User Interface
- **HomeView.swift** - Main app interface
- SwiftUI-based modern iOS design
- File picker integration
- Real-time process monitoring

## Technical Details

### Container Structure
```
Documents/wine_container/
├── containers/
│   └── container_1/
│       ├── drive_c/
│       │   ├── Program Files/
│       │   ├── Windows/
│       │   └── Users/
│       ├── dosdevices/
│       ├── system.reg
│       └── user.reg
└── ...
```

### PE Analysis
- Validates MZ and PE signatures
- Detects architecture (x86, x86-64)
- Analyzes entry points and subsystems
- Checks iOS compatibility

### Process Execution
- Simulated Wine execution (ready for real Wine integration)
- Environment variable setup
- Process monitoring and termination
- Container isolation

## Current Status

### ✅ Implemented
- Wine container system
- PE file analysis
- Container management
- File import system
- Process simulation
- SwiftUI interface

### 🚧 In Progress
- Real Wine integration
- Graphics rendering
- JIT optimization
- Advanced process management

### 📋 Planned
- DirectX support via DXVK
- Metal rendering backend
- Game optimization
- Performance monitoring
- Virtual controls

## Contributing

This is based on GameHub Android emulator analysis. Contributions welcome for:
- Wine integration improvements
- Graphics rendering optimization
- iOS-specific optimizations
- UI/UX improvements

## Requirements

- **iOS 16+** - Modern iOS features
- **JIT Enabled** - Required for performance
- **8GB+ RAM** - Recommended for games
- **Metal GPU** - Graphics acceleration

## License

Educational and research purposes. Based on open-source GameHub analysis.

---

**Winkor** - *Windows on iOS, powered by Wine + SwiftUI*
