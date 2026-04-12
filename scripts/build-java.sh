#!/bin/bash
# build-java.sh - Package SWIG Java code into JAR
# Usage: ./build-java.sh <java-source-dir> <output-jar>

set -e

SOURCE_DIR="${1:-$PWD/../quantlib4j-java/src/main/java}"
OUTPUT_JAR="${2:-$PWD/../quantlib4j-java/target/quantlib4j-1.34.jar}"
VERSION="1.34"

echo "=== Package Java Code into JAR ==="
echo "Source Directory: $SOURCE_DIR"
echo "Output JAR: $OUTPUT_JAR"

# Create temp bin directory
mkdir -p .tmp_bin

# Compile Java files
echo "Compiling Java files..."
find "$SOURCE_DIR" -name "*.java" > sources.txt
javac -d .tmp_bin @sources.txt

# Create JAR
echo "Creating JAR..."
mkdir -p target
jar cf "$OUTPUT_JAR" -C .tmp_bin com

# Add manifest
echo "Manifest-Version: 1.0" > MANIFEST.MF
echo "QuantLib-Version: $VERSION" >> MANIFEST.MF
echo "QuantLib-Package: com.luopc.platform.quantlib" >> MANIFEST.MF

jar cfm "$OUTPUT_JAR" MANIFEST.MF -C .tmp_bin com

# Cleanup
rm -rf .tmp_bin sources.txt MANIFEST.MF

echo "JAR created: $OUTPUT_JAR"
echo "Size: $(ls -lh "$OUTPUT_JAR" | awk '{print $5}')"
