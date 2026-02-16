#!/bin/bash
# Build Mesa (VirGL + Turnip) for iOS
# Mesa provides: VirGL (OpenGL→Metal), Turnip (Vulkan driver)
# These are the GPU drivers that translate graphics calls

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/mesa"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/mesa"
MESA_VERSION="24.0.0"
MESA_REPO="https://gitlab.freedesktop.org/mesa/mesa.git"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="16.0"
ARCH="arm64"

echo "=== Building Mesa $MESA_VERSION for iOS ==="
echo "Components: VirGL, Turnip, swrast"

# Clone Mesa
if [ ! -d "$BUILD_DIR/mesa-src" ]; then
    echo "Cloning Mesa..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "mesa-$MESA_VERSION" "$MESA_REPO" "$BUILD_DIR/mesa-src" || \
    git clone --depth 1 "$MESA_REPO" "$BUILD_DIR/mesa-src"
fi

cd "$BUILD_DIR/mesa-src"

# Create Meson cross-compilation file for iOS
cat > ios-cross.txt << EOF
[binaries]
c = '$(xcrun --sdk iphoneos --find clang)'
cpp = '$(xcrun --sdk iphoneos --find clang++)'
ar = '$(xcrun --sdk iphoneos --find ar)'
strip = '$(xcrun --sdk iphoneos --find strip)'

[built-in options]
c_args = ['-arch', 'arm64', '-isysroot', '$IOS_SDK', '-miphoneos-version-min=$IOS_MIN_VERSION']
cpp_args = ['-arch', 'arm64', '-isysroot', '$IOS_SDK', '-miphoneos-version-min=$IOS_MIN_VERSION']
c_link_args = ['-arch', 'arm64', '-isysroot', '$IOS_SDK']
cpp_link_args = ['-arch', 'arm64', '-isysroot', '$IOS_SDK']

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
EOF

# Configure Mesa with Meson
meson setup build-ios \
    --cross-file ios-cross.txt \
    --prefix="$OUTPUT_DIR" \
    -Dgallium-drivers=virgl,swrast \
    -Dvulkan-drivers=freedreno \
    -Dplatforms= \
    -Dglx=disabled \
    -Degl=disabled \
    -Dgbm=disabled \
    -Dgles1=disabled \
    -Dgles2=enabled \
    -Dopengl=true \
    -Dshared-glapi=enabled \
    -Dllvm=disabled \
    -Dbuildtype=release \
    -Dstrip=true

# Build
echo "Building Mesa..."
ninja -C build-ios

# Install
echo "Installing Mesa..."
ninja -C build-ios install

echo "=== Mesa build complete ==="
echo "VirGL: $OUTPUT_DIR/lib/libvirgl*.dylib"
echo "Turnip: $OUTPUT_DIR/lib/libvulkan_freedreno*.dylib"
echo "Mesa GL: $OUTPUT_DIR/lib/libGL*.dylib"
