#!/bin/bash
# build-swig.sh - Generate SWIG Java code with custom package name
# Usage: ./build-swig.sh <swig-dir> <output-dir>
#
# Example: ./build-swig.sh /path/to/QuantLib-SWIG ./generated

set -e

SWIG_DIR="${1:-$PWD/../../../QuantLib-SWIG}"
OUTPUT_DIR="${2:-$PWD/../quantlib4j-java/src/main/java}"

JAVA_PACKAGE="com.luopc.platform.quantlib"
MODULE_NAME="quantlib4j"

echo "=== QuantLib SWIG Java Code Generator ==="
echo "SWIG Directory: $SWIG_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "Package: $JAVA_PACKAGE"
echo "Module: $MODULE_NAME"

# Check prerequisites
if ! command -v swig &> /dev/null; then
    echo "Error: SWIG not found. Please install SWIG 4.2+"
    exit 1
fi

SWIG_VERSION=$(swig -version | head -n1 | awk '{print $3}')
echo "SWIG Version: $SWIG_VERSION"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate Java code with custom package
echo "Generating Java code..."
cd "$SWIG_DIR/SWIG"

swig -c++ -java \
    -package "$JAVA_PACKAGE" \
    -outdir "$OUTPUT_DIR" \
    -o quantlib_wrap.cpp \
    quantlib.i

echo "Java code generated successfully!"
echo "Files: $(ls -1 $OUTPUT_DIR | wc -l)"

# List generated files
echo ""
echo "Generated files:"
ls -la "$OUTPUT_DIR"
