#!/bin/bash
# Winkor - Full Environment Setup Script
# Builds ALL dependencies needed for the Windows emulator on iOS
# Run this once to set up the complete build environment

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_DIR="$BUILD_DIR/output"

echo "╔══════════════════════════════════════════╗"
echo "║     Winkor - Full Environment Setup      ║"
echo "║  Windows Emulator for iOS (like Winlator)║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "  ✓ $1 found"
        return 0
    else
        echo "  ✗ $1 NOT found"
        return 1
    fi
}

check_tool "xcodebuild" || { echo "ERROR: Xcode not installed"; exit 1; }
check_tool "cmake" || { echo "WARNING: cmake needed for Box64"; }
check_tool "meson" || { echo "WARNING: meson needed for Mesa/DXVK"; }
check_tool "ninja" || { echo "WARNING: ninja needed for Mesa/DXVK"; }
check_tool "git" || { echo "ERROR: git not installed"; exit 1; }

echo ""
echo "Build order:"
echo "  1. MoltenVK (Vulkan → Metal)"
echo "  2. Mesa (VirGL + Turnip GPU drivers)"
echo "  3. Box64 (x86-64 → ARM64 CPU translator)"
echo "  4. Wine (Windows API compatibility)"
echo "  5. DXVK (DirectX → Vulkan)"
echo ""

mkdir -p "$OUTPUT_DIR"

# Step 1: MoltenVK
echo "═══ Step 1/5: Building MoltenVK ═══"
bash "$SCRIPT_DIR/build-moltenvk.sh"
echo ""

# Step 2: Mesa
echo "═══ Step 2/5: Building Mesa ═══"
bash "$SCRIPT_DIR/build-mesa.sh"
echo ""

# Step 3: Box64
echo "═══ Step 3/5: Building Box64 ═══"
bash "$SCRIPT_DIR/build-box64.sh"
echo ""

# Step 4: Wine
echo "═══ Step 4/5: Building Wine ═══"
bash "$SCRIPT_DIR/build-wine.sh"
echo ""

# Step 5: DXVK
echo "═══ Step 5/5: Building DXVK ═══"
bash "$SCRIPT_DIR/build-dxvk.sh"
echo ""

echo "╔══════════════════════════════════════════╗"
echo "║         Build Complete!                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Components built:"
ls -la "$OUTPUT_DIR/" 2>/dev/null
echo ""
echo "Next steps:"
echo "  1. Run the GitHub Actions workflow to build the .ipa"
echo "  2. Or build locally with: xcodebuild (after xcodegen)"
echo ""
echo "Architecture: ARM64 (iOS)"
echo "Graphics pipeline: DirectX → DXVK → Vulkan → MoltenVK → Metal → GPU"
echo "CPU pipeline: x86-64 → Box64 (dynarec) → ARM64"
echo "API pipeline: Win32 API → Wine → iOS/POSIX"
