#!/bin/bash
# build-native.sh - Build native library for current platform
# Usage: ./build-native.sh [PLATFORM]
#
# Platforms: linux, windows, macos
# Example: ./build-native.sh linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
QUANTLIB_VERSION="${QUANTLIB_VERSION:-1.34}"
PROJECT_VERSION="${PROJECT_VERSION:-1.3.5-SNAPSHOT}"

PLATFORM="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

echo "=============================================="
echo "  QuantLib4J Native Build"
echo "=============================================="
echo "Platform: $PLATFORM"
echo "QuantLib Version: $QUANTLIB_VERSION"
echo "Project Version: $PROJECT_VERSION"
echo "=============================================="

case "$PLATFORM" in
    linux)
        echo "Building for Linux..."
        build_linux
        ;;
    macos|darwin)
        echo "Building for macOS..."
        build_macos
        ;;
    windows|*)
        echo "Building for Windows..."
        echo "Please use build-native.bat on Windows"
        exit 1
        ;;
esac

echo ""
echo "Native library built successfully!"
