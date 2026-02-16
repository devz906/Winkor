#!/bin/bash
# Build Wine for iOS (ARM64)
# Wine provides the Windows API compatibility layer
# This cross-compiles Wine to run on iOS via Box64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/wine"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/wine"
WINE_VERSION="9.0"
WINE_REPO="https://github.com/wine-mirror/wine.git"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="16.0"
ARCH="arm64"

echo "=== Building Wine $WINE_VERSION for iOS ==="
echo "SDK: $IOS_SDK"
echo "Min iOS: $IOS_MIN_VERSION"

# Clone Wine
if [ ! -d "$BUILD_DIR/wine-src" ]; then
    echo "Cloning Wine..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "wine-$WINE_VERSION" "$WINE_REPO" "$BUILD_DIR/wine-src" || \
    git clone --depth 1 "$WINE_REPO" "$BUILD_DIR/wine-src"
fi

cd "$BUILD_DIR/wine-src"

# Configure Wine for iOS cross-compilation
# Wine needs both 64-bit and 32-bit (WoW64) builds
mkdir -p build-ios64
cd build-ios64

../configure \
    --prefix="$OUTPUT_DIR" \
    --host=aarch64-apple-darwin \
    --with-wine-tools="$BUILD_DIR/wine-tools" \
    --enable-win64 \
    --without-x \
    --without-freetype \
    --without-pulse \
    --without-alsa \
    --without-oss \
    --without-cups \
    --without-gphoto \
    --without-sane \
    --without-v4l2 \
    --without-usb \
    --without-capi \
    --without-hal \
    --without-dbus \
    --without-gstreamer \
    CC="$(xcrun --sdk iphoneos --find clang) -arch $ARCH -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION" \
    CXX="$(xcrun --sdk iphoneos --find clang++) -arch $ARCH -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION" \
    LDFLAGS="-arch $ARCH -isysroot $IOS_SDK"

# Build
echo "Building Wine..."
make -j$(sysctl -n hw.ncpu)

# Install
echo "Installing Wine..."
make install

echo "=== Wine build complete ==="
echo "Wine binary: $OUTPUT_DIR/bin/wine64"
echo "Wine server: $OUTPUT_DIR/bin/wineserver"
echo "Wine libs: $OUTPUT_DIR/lib/"
