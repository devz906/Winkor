#!/bin/bash
# Build DXVK for use with Wine on iOS
# DXVK translates DirectX 9/10/11 to Vulkan
# These DLLs run inside Wine (x86-64) so they need to be built for Windows/x86-64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/dxvk"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/dxvk"
DXVK_VERSION="2.3.1"
DXVK_REPO="https://github.com/doitsujin/dxvk.git"

echo "=== Building DXVK $DXVK_VERSION ==="
echo "DXVK DLLs are Windows PE binaries that run inside Wine"
echo "They need MinGW cross-compiler (x86-64 Windows target)"

# Install MinGW if not present (macOS)
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "Installing MinGW cross-compiler..."
    brew install mingw-w64 || true
fi

# Clone DXVK
if [ ! -d "$BUILD_DIR/dxvk-src" ]; then
    echo "Cloning DXVK..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "v$DXVK_VERSION" "$DXVK_REPO" "$BUILD_DIR/dxvk-src" || \
    git clone --depth 1 "$DXVK_REPO" "$BUILD_DIR/dxvk-src"
fi

cd "$BUILD_DIR/dxvk-src"

# Build DXVK using Meson with MinGW cross-compilation
# 64-bit build
meson setup --cross-file build-win64.txt \
    --buildtype release \
    --strip \
    --prefix="$OUTPUT_DIR/x64" \
    build.w64

ninja -C build.w64
ninja -C build.w64 install

# 32-bit build
meson setup --cross-file build-win32.txt \
    --buildtype release \
    --strip \
    --prefix="$OUTPUT_DIR/x32" \
    build.w32

ninja -C build.w32
ninja -C build.w32 install

echo "=== DXVK build complete ==="
echo "64-bit DLLs: $OUTPUT_DIR/x64/"
echo "32-bit DLLs: $OUTPUT_DIR/x32/"
echo ""
echo "DLLs built:"
ls -la "$OUTPUT_DIR/x64/bin/" 2>/dev/null || echo "  (build may have failed)"
echo ""
echo "These DLLs override d3d9.dll, d3d10core.dll, d3d11.dll, dxgi.dll in Wine's System32"
