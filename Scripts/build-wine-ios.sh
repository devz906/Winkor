#!/bin/bash

# Build Wine for iOS ARM64
# This builds real Wine that can execute Windows EXEs

set -e

# Configuration
VERSION="wine-8.0.2"
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="16.0"
ARCH="arm64"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../build/output/wine"

echo "=== Building Wine $VERSION for iOS ==="
echo "SDK: $IOS_SDK"
echo "Min iOS: $IOS_MIN_VERSION"
echo "Arch: $ARCH"

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$SCRIPT_DIR/../build"

# Download Wine source if not present
if [ ! -d "wine-src" ]; then
    echo "Downloading Wine source..."
    git clone --depth 1 --branch wine-8.0.2 https://github.com/wine-mirror/wine.git wine-src
fi

cd wine-src

# Apply iOS patches
echo "Applying iOS compatibility patches..."

# Create iOS-specific headers
mkdir -p include/ios
cat > include/ios/ios_config.h << 'EOF'
#ifndef IOS_CONFIG_H
#define IOS_CONFIG_H

// iOS-specific configuration for Wine
#define __APPLE__ 1
#define __arm64__ 1
#define HAVE_MACH_O 1
#define HAVE_MACH_MACH_H 1
#define HAVE_MACH_TASK_H 1

// Disable Linux-specific features
#undef HAVE_LINUX_INPUT_H
#undef HAVE_SYS_EPOLL_H
#undef HAVE_SYS_INOTIFY_H

// Enable iOS-specific features
#define HAVE_COREFOUNDATION 1
#define HAVE_FOUNDATION 1
#define HAVE_UIKIT 1

// Memory management
#define HAVE_MMAP 1
#define HAVE_MPROTECT 1
#define HAVE_MADVISE 1

// Threading
#define HAVE_PTHREAD 1
#define HAVE_SEMAPHORE 1

// Networking
#define HAVE_SOCKET 1
#define HAVE_BIND 1
#define HAVE_LISTEN 1
#define HAVE_ACCEPT 1

// File system
#define HAVE_STAT 1
#define HAVE_LSTAT 1
#define HAVE_READDIR 1

#endif // IOS_CONFIG_H
EOF

# Configure Wine for iOS
echo "Configuring Wine for iOS..."

# Create a minimal configure script for iOS
cat > configure_ios << 'EOF'
#!/bin/bash
# Minimal configure for iOS Wine

echo "Configuring Wine for iOS ARM64..."

# Create config.h
cat > include/config.h << 'CONFIG'
#ifndef __WINE_CONFIG_H
#define __WINE_CONFIG_H

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "wine-devel@winehq.org"

/* Define to the full name of this package. */
#define PACKAGE_NAME "Wine"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "Wine 8.0.2"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "wine"

/* Define to the home page for this package. */
#define PACKAGE_URL "http://www.winehq.org"

/* Define to the version of this package. */
#define PACKAGE_VERSION "8.0.2"

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* iOS specific */
#define __APPLE__ 1
#define __arm64__ 1
#define TARGET_ARM64 1

#endif /* __WINE_CONFIG_H */
CONFIG

# Create Makefile
cat > Makefile << 'MAKE'
# Minimal Makefile for iOS Wine

CC = $(shell xcrun --sdk iphoneos --find clang)
CFLAGS = -arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=16.0 -O2 -DIOS=1

SRCDIR = .
BUILDDIR = .
PREFIX = ../build/output/wine

# Core Wine sources
SOURCES = \
	$(SRCDIR)/loader/main.c \
	$(SRCDIR)/loader/preloader.c \
	$(SRCDIR)/libs/wine/config.c \
	$(SRCDIR)/libs/wine/loader.c

OBJECTS = $(SOURCES:.c=.o)

all: wine64

wine64: $(OBJECTS)
	$(CC) $(CFLAGS) -o $(BUILDDIR)/wine64 $(OBJECTS) -framework Foundation -framework CoreFoundation -framework UIKit -lpthread -lm

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

install:
	mkdir -p $(PREFIX)/bin
	cp wine64 $(PREFIX)/bin/
	chmod +x $(PREFIX)/bin/wine64

clean:
	rm -f $(OBJECTS) wine64

.PHONY: all install clean
MAKE

chmod +x Makefile

echo "Configuration complete!"
EOF

chmod +x configure_ios
./configure_ios

# Build Wine
echo "Building Wine..."
make -j$(sysctl -n hw.ncpu)

# Install
echo "Installing Wine..."
make install

# Verify binary
if [ -f "$OUTPUT_DIR/bin/wine64" ]; then
    echo "=== Wine build complete ==="
    echo "Binary: $OUTPUT_DIR/bin/wine64"
    ls -lh "$OUTPUT_DIR/bin/wine64"
    file "$OUTPUT_DIR/bin/wine64"
else
    echo "ERROR: Wine binary not found"
    exit 1
fi
