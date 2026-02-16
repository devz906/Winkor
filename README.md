# Winkor - Windows Emulator for iOS

**Run Windows applications and games on iPhone/iPad — Winlator ported to iOS**

[![Build Winkor IPA](https://github.com/ezzid29-coder/Winkor/actions/workflows/build.yml/badge.svg)](https://github.com/ezzid29-coder/Winkor/actions/workflows/build.yml)

## What is Winkor?

Winkor is an iOS port of the Winlator concept — a full Windows emulation environment that lets you run Windows `.exe` files, games, and applications on your iPhone or iPad. It combines multiple open-source projects into one app:

| Component | Purpose |
|-----------|---------|
| **Box64** | Translates x86-64 CPU instructions → ARM64 (the CPU your iPhone uses) |
| **Wine** | Translates Windows API calls → iOS/POSIX (makes apps think they're on Windows) |
| **DXVK** | Translates DirectX 9/10/11 → Vulkan (for game graphics) |
| **VKD3D-Proton** | Translates DirectX 12 → Vulkan |
| **MoltenVK** | Translates Vulkan → Metal (Apple's GPU API) |
| **VirGL** | Translates OpenGL → Metal (for OpenGL games) |
| **Mesa** | Graphics driver stack (Turnip Vulkan + VirGL OpenGL) |

## How It Works

```
Windows Game/App (.exe)
        │
        ▼
   ┌─────────┐
   │  Box64   │  x86-64 instructions → ARM64 instructions
   └────┬────┘
        │
        ▼
   ┌─────────┐
   │  Wine    │  Win32 API calls → iOS/POSIX system calls
   └────┬────┘
        │
   ┌────┴─────────────────────┐
   │                          │
   ▼                          ▼
┌──────┐              ┌───────────┐
│ DXVK │ DirectX→Vk   │  VirGL    │ OpenGL→Metal
└──┬───┘              └─────┬─────┘
   │                        │
   ▼                        │
┌──────────┐                │
│ MoltenVK │ Vulkan→Metal   │
└────┬─────┘                │
     │                      │
     └──────────┬───────────┘
                │
                ▼
         ┌───────────┐
         │   Metal   │  Apple's GPU API
         └─────┬─────┘
               │
               ▼
         ┌───────────┐
         │  iOS GPU   │  A-series / M-series chip
         └───────────┘
```

## Features

- **Container System** — Create multiple isolated Windows environments (like Winlator)
- **GPU Driver Downloads** — Download Turnip, VirGL, Mesa, DXVK, MoltenVK from the app
- **DX Wrapper Selection** — Choose DXVK, VKD3D-Proton, WineD3D, or D8VK per container
- **Box64 Presets** — Default, Performance, Gaming, Compatibility modes
- **Windows Version Emulation** — XP, 7, 8.1, 10, 11
- **Resolution Control** — 640x480 to 2560x1440
- **DLL Override Management** — Control native vs builtin DLL loading
- **JIT Status & Management** — Detect and enable JIT for Box64 dynarec
- **PE File Analysis** — Read and analyze Windows .exe files
- **On-Screen Controls** — Virtual gamepad for controller-based games
- **Wine Console** — Real-time output from Wine/Box64 execution
- **File Import** — Import .exe files from Files app

## Requirements

- **iOS 16+** device (iPhone or iPad)
- **ARM64** processor (all modern iPhones/iPads)
- **JIT enabled** (via SideJITServer, JITStreamer, AltJIT, or jailbreak)
- **8GB+ RAM** recommended for games
- **Metal GPU** support (all devices since iPhone 6s)
- Sideloading method (AltStore, SideStore, TrollStore, or Xcode)

## Installation

### Method 1: Download IPA from GitHub Actions
1. Go to the [Actions tab](https://github.com/ezzid29-coder/Winkor/actions)
2. Click the latest successful build
3. Download the **Winkor-IPA** artifact
4. Sideload the `.ipa` with AltStore, SideStore, or TrollStore

### Method 2: Build from Source
```bash
# Clone the repo
git clone https://github.com/ezzid29-coder/Winkor.git
cd Winkor

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open in Xcode
open Winkor.xcodeproj

# Build for iOS device (not simulator)
```

## Enabling JIT

JIT is **required** for Box64's dynamic recompiler. Without it, everything runs in slow interpreter mode.

| Method | Difficulty | Notes |
|--------|-----------|-------|
| **SideJITServer** | Easy | Companion PC app, enables over WiFi |
| **JITStreamer** | Easy | iOS Shortcut, no PC needed |
| **AltJIT** | Easy | Built into AltStore |
| **Xcode** | Medium | Run from Xcode with debugger |
| **TrollStore** | Easy | If available for your iOS version |

## Project Structure

```
Winkor/
├── .github/workflows/build.yml     # GitHub Actions → builds .ipa artifact
├── WinkorApp/
│   ├── Main.swift                   # App entry point
│   ├── Info.plist                   # iOS app configuration
│   ├── Core/
│   │   ├── Box64Bridge.swift        # Box64 x86-64→ARM64 integration
│   │   ├── WineEngine.swift         # Wine Windows API layer
│   │   ├── ContainerManager.swift   # Wine container management
│   │   ├── JITManager.swift         # JIT detection and enablement
│   │   ├── DriverManager.swift      # GPU/DX driver downloads
│   │   ├── FileSystemManager.swift  # Windows filesystem emulation
│   │   └── ProcessManager.swift     # Launch chain orchestration
│   ├── Emulation/
│   │   ├── PELoader.swift           # Windows PE file parser
│   │   ├── MemoryManager.swift      # Virtual memory management
│   │   ├── WindowsAPI.swift         # Win32 API stubs
│   │   └── DLLLoader.swift          # DLL loading and overrides
│   ├── Graphics/
│   │   ├── MetalRenderer.swift      # Metal rendering backend
│   │   ├── DXVKTranslator.swift     # DXVK DirectX→Vulkan config
│   │   ├── VirGLRenderer.swift      # VirGL OpenGL→Metal config
│   │   └── Shaders.metal            # Metal GPU shaders
│   └── Views/
│       ├── HomeView.swift           # Container list (home screen)
│       ├── CreateContainerView.swift # New container wizard
│       ├── ContainerSettingsView.swift # Container config editor
│       ├── DesktopView.swift        # Windows desktop environment
│       ├── DriverManagerView.swift  # Component download manager
│       └── SettingsView.swift       # App settings & JIT config
├── Scripts/
│   ├── build-box64.sh              # Build Box64 for iOS
│   ├── build-wine.sh               # Build Wine for iOS
│   ├── build-mesa.sh               # Build Mesa/VirGL/Turnip
│   ├── build-dxvk.sh               # Build DXVK DLLs
│   ├── build-moltenvk.sh           # Build MoltenVK
│   └── setup-environment.sh        # Full setup script
├── project.yml                      # XcodeGen project definition
└── README.md
```

## For Big Games

To run large games (GTA, Fallout, etc.), you need:

1. **Gaming preset** in Box64 settings (aggressive dynarec)
2. **DXVK** enabled (most games use DirectX)
3. **Turnip Vulkan** driver (best performance)
4. **JIT enabled** (absolutely required)
5. **High RAM** (4096+ MB allocated to container)
6. **Lower resolution** (720p or lower for complex games)
7. Import the game files to the container's `C:\Program Files\` directory

## Graphics Driver Guide

| Game Uses | You Need | DX Wrapper |
|-----------|----------|------------|
| DirectX 9 | DXVK + MoltenVK + Turnip | DXVK |
| DirectX 10/11 | DXVK + MoltenVK + Turnip | DXVK |
| DirectX 12 | VKD3D-Proton + MoltenVK + Turnip | DXVK + VKD3D |
| OpenGL | VirGL + Mesa | WineD3D or VirGL |
| Vulkan | MoltenVK + Turnip | (native) |

## Contributing

This is a massive project — contributions welcome:
- Wine porting improvements for iOS
- Box64 iOS optimizations
- DXVK/Mesa/MoltenVK integration
- UI/UX improvements
- Game compatibility testing
- Documentation

## Credits

- **[Box64](https://github.com/ptitSeb/box64)** — x86-64 emulator by ptitSeb
- **[Wine](https://www.winehq.org/)** — Windows API compatibility layer
- **[DXVK](https://github.com/doitsujin/dxvk)** — DirectX to Vulkan translation
- **[VKD3D-Proton](https://github.com/HansKristian-Work/vkd3d-proton)** — DirectX 12 to Vulkan
- **[MoltenVK](https://github.com/KhronosGroup/MoltenVK)** — Vulkan to Metal translation
- **[Mesa](https://www.mesa3d.org/)** — Open-source GPU drivers (VirGL, Turnip)
- **[Winlator](https://github.com/nicknsy/winlator)** — Original Android implementation (inspiration)

## License

This project is for educational and research purposes.

---

**Winkor** — *Windows on iOS, powered by Wine + Box64 + DXVK + Metal*
