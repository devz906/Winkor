#!/bin/bash
# Build Box64 for iOS (ARM64)
# Box64 is the x86-64 to ARM64 dynamic recompiler
# This script cross-compiles Box64 for iOS devices

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/box64"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/box64"
BOX64_VERSION="0.3.2"
BOX64_REPO="https://github.com/ptitSeb/box64.git"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="16.0"
ARCH="arm64"

echo "=== Building Box64 $BOX64_VERSION for iOS ==="
echo "SDK: $IOS_SDK"
echo "Min iOS: $IOS_MIN_VERSION"
echo "Arch: $ARCH"

# Clone Box64
if [ ! -d "$BUILD_DIR/box64-src" ]; then
    echo "Cloning Box64..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "v$BOX64_VERSION" "$BOX64_REPO" "$BUILD_DIR/box64-src" || \
    git clone --depth 1 "$BOX64_REPO" "$BUILD_DIR/box64-src"
fi

cd "$BUILD_DIR/box64-src"

# Create build directory
mkdir -p build-ios
cd build-ios

# Configure with CMake for iOS cross-compilation
cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
    -DCMAKE_OSX_SYSROOT=$IOS_SDK \
    -DCMAKE_C_COMPILER=$(xcrun --sdk iphoneos --find clang) \
    -DCMAKE_C_FLAGS="-arch $ARCH -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION" \
    -DARM_DYNAREC=ON \
    -DIOS=ON \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"

# Build
echo "Building Box64..."
make -j$(sysctl -n hw.ncpu)

# Install
echo "Installing Box64..."
mkdir -p "$OUTPUT_DIR/bin"
mkdir -p "$OUTPUT_DIR/lib"
cp box64 "$OUTPUT_DIR/bin/" 2>/dev/null || true
cp -r ../x64lib/* "$OUTPUT_DIR/lib/" 2>/dev/null || true

echo "=== Box64 build complete ==="
echo "Binary: $OUTPUT_DIR/bin/box64"
echo "Libraries: $OUTPUT_DIR/lib/"
