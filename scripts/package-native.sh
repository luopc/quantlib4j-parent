#!/bin/bash
# package-native.sh - Package native library into JAR with classifier
# Usage: ./package-native.sh <platform> <native-lib-path>

set -e

PLATFORM="${1}"
NATIVE_LIB="${2}"
OUTPUT_DIR="${3:-.}/target"

echo "=== Package Native Library ==="
echo "Platform: $PLATFORM"
echo "Native Library: $NATIVE_LIB"
echo "Output Directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

case "$PLATFORM" in
    linux-x64)
        OUTPUT_JAR="$OUTPUT_DIR/quantlib4j-1.34-linux-x64.jar"
        cp "$NATIVE_LIB" libquantlib4j.so
        jar cf "$OUTPUT_JAR" libquantlib4j.so
        ;;
    windows-x64)
        OUTPUT_JAR="$OUTPUT_DIR/quantlib4j-1.34-windows-x64.jar"
        cp "$NATIVE_LIB" quantlib4j.dll
        jar cf "$OUTPUT_JAR" quantlib4j.dll
        ;;
    macos-x64)
        OUTPUT_JAR="$OUTPUT_DIR/quantlib4j-1.34-macos-x64.jar"
        cp "$NATIVE_LIB" libquantlib4j.dylib
        jar cf "$OUTPUT_JAR" libquantlib4j.dylib
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

echo "JAR created: $OUTPUT_JAR"
