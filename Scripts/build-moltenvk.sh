#!/bin/bash
# Build MoltenVK for iOS
# MoltenVK translates Vulkan API calls to Metal API calls
# This is the bridge between Vulkan (from DXVK/games) and Apple's Metal GPU API

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/moltenvk"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/moltenvk"
MVK_VERSION="1.2.8"
MVK_REPO="https://github.com/KhronosGroup/MoltenVK.git"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)

echo "=== Building MoltenVK $MVK_VERSION for iOS ==="

# Clone MoltenVK
if [ ! -d "$BUILD_DIR/MoltenVK-src" ]; then
    echo "Cloning MoltenVK..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "v$MVK_VERSION" "$MVK_REPO" "$BUILD_DIR/MoltenVK-src" || \
    git clone --depth 1 "$MVK_REPO" "$BUILD_DIR/MoltenVK-src"
fi

cd "$BUILD_DIR/MoltenVK-src"

# Fetch dependencies (SPIRV-Cross, Vulkan-Headers, etc.)
echo "Fetching MoltenVK dependencies..."
./fetchDependencies --ios

# Build MoltenVK for iOS
echo "Building MoltenVK for iOS..."
make ios

# Copy output
mkdir -p "$OUTPUT_DIR/lib"
mkdir -p "$OUTPUT_DIR/include"

cp -r Package/Release/MoltenVK/MoltenVK.xcframework/ios-arm64/libMoltenVK.a "$OUTPUT_DIR/lib/" 2>/dev/null || true
cp -r Package/Release/MoltenVK/dylib/iOS/libMoltenVK.dylib "$OUTPUT_DIR/lib/" 2>/dev/null || true
cp -r Package/Release/MoltenVK/include/* "$OUTPUT_DIR/include/" 2>/dev/null || true

# Also copy Vulkan ICD JSON
cat > "$OUTPUT_DIR/lib/MoltenVK_icd.json" << EOF
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "libMoltenVK.dylib",
        "api_version": "1.2.0"
    }
}
EOF

echo "=== MoltenVK build complete ==="
echo "Library: $OUTPUT_DIR/lib/libMoltenVK.dylib"
echo "Headers: $OUTPUT_DIR/include/"
echo "ICD: $OUTPUT_DIR/lib/MoltenVK_icd.json"
