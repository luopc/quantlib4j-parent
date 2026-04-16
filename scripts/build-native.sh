#!/bin/bash
# build-native.sh - Build QuantLib4J Native Library on Linux
# Usage: ./build-native.sh [--skip-deps] [--skip-swig] [--skip-build]
#
# Options:
#   --skip-deps   Skip installing dependencies
#   --skip-swig   Skip SWIG generation
#   --skip-build  Skip native library compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
JAVA_PACKAGE="com.luopc.platform.quantlib"
PROJECT_VERSION="${PROJECT_VERSION:-1.3.5-SNAPSHOT}"
QUANTLIB_VERSION="${QUANTLIB_VERSION:-1.42}"

# Default values
SKIP_DEPS=false
SKIP_SWIG=false
SKIP_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-deps) SKIP_DEPS=true; shift ;;
        --skip-swig) SKIP_SWIG=true; shift ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-deps   Skip installing dependencies"
            echo "  --skip-swig   Skip SWIG generation"
            echo "  --skip-build  Skip native library compilation"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=============================================="
echo "  QuantLib4J Native Build (Linux)"
echo "=============================================="
echo "Workspace:         $WORKSPACE"
echo "QuantLib Version:  $QUANTLIB_VERSION"
echo "Java Package:      $JAVA_PACKAGE"
echo "Project Version:   $PROJECT_VERSION"
echo "=============================================="

# Step 1: Install dependencies
if [ "$SKIP_DEPS" != "true" ]; then
    echo ""
    echo "[1/5] Installing dependencies..."

    if command -v dnf &> /dev/null; then
        # AlmaLinux/RHEL/Fedora
        sudo dnf install -y \
            gcc-c++ \
            make \
            cmake \
            boost-devel \
            libicu-devel \
            wget \
            tar \
            gzip
    elif command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            cmake \
            libboost-all-dev \
            libicu-dev \
            wget \
            tar \
            gzip
    fi

    echo "OK: Dependencies installed"
else
    echo ""
    echo "[1/5] Skipping dependencies (--skip-deps)"
fi

# Step 2: Build and install SWIG
SWIG_VERSION="4.4.1"
if ! command -v swig &> /dev/null || ! swig -version 2>/dev/null | grep -q "4.4"; then
    echo ""
    echo "[2/5] Building SWIG $SWIG_VERSION..."

    if [ ! -f "swig-$SWIG_VERSION.tar.gz" ]; then
        wget --no-check-certificate "https://lb.luopc.com/nexus/repository/maven-releases/org/swig/swig/$SWIG_VERSION/swig-$SWIG_VERSION.tar.gz"
    fi

    tar -xzf swig-$SWIG_VERSION.tar.gz
    cd swig-$SWIG_VERSION
    ./configure --without-pcre --without-pcre2
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf swig-$SWIG_VERSION

    export PATH="/usr/local/bin:$PATH"
    echo "OK: SWIG installed"
else
    echo ""
    echo "[2/5] SWIG already installed: $(swig -version | head -1)"
fi

# Step 3: Build QuantLib
if ! pkg-config --exists quantlib 2>/dev/null; then
    echo ""
    echo "[3/5] Building QuantLib $QUANTLIB_VERSION..."

    if [ ! -f "QuantLib-$QUANTLIB_VERSION.tar.gz" ]; then
        wget --no-check-certificate "https://lb.luopc.com/nexus/repository/maven-releases/org/quantlib/QuantLib/$QUANTLIB_VERSION/QuantLib-$QUANTLIB_VERSION.tar.gz"
    fi

    tar -xzf QuantLib-$QUANTLIB_VERSION.tar.gz
    cd QuantLib-$QUANTLIB_VERSION
    ./configure --enable-thread-safe-observer-pattern
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ..
    rm -rf QuantLib-$QUANTLIB_VERSION

    echo "OK: QuantLib installed"
else
    echo ""
    echo "[3/5] QuantLib already installed"
    pkg-config --libs quantlib
fi

# Ensure pkg-config can find QuantLib
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
sudo ldconfig

# Step 4: Generate SWIG Java bindings
if [ "$SKIP_SWIG" != "true" ]; then
    echo ""
    echo "[4/5] Generating SWIG Java bindings..."

    # Check if QuantLib-SWIG exists
    if [ -d "$WORKSPACE/../QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/../QuantLib-SWIG"
    elif [ -d "$WORKSPACE/QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/QuantLib-SWIG"
    else
        echo "ERROR: QuantLib-SWIG not found"
        echo "Please clone: git clone https://github.com/ValHallas/QuantLib-SWIG.git ../QuantLib-SWIG"
        exit 1
    fi

    # Create output directory
    mkdir -p "$WORKSPACE/quantlib4j-java/src/main/java/com/luopc/platform/quantlib"

    # Generate SWIG bindings
    cd "$SWIG_DIR/SWIG"
    swig -c++ -java \
        -package "$JAVA_PACKAGE" \
        -outdir "$WORKSPACE/quantlib4j-java/src/main/java/com/luopc/platform/quantlib" \
        -o "$WORKSPACE/quantlib_wrap.cpp" \
        quantlib.i

    echo "OK: SWIG bindings generated"
else
    echo ""
    echo "[4/5] Skipping SWIG generation (--skip-swig)"
fi

# Step 5: Build native library
if [ "$SKIP_BUILD" != "true" ]; then
    echo ""
    echo "[5/5] Building native library..."

    cd "$WORKSPACE"

    # Build quantlib4j-java
    echo "Building quantlib4j-java..."
    mvn clean install -pl quantlib4j-java -DskipTests

    # Build native library
    echo "Compiling libquantlib4j.so..."
    mkdir -p quantlib4j-native-linux/src/main/resources
    g++ -shared -fPIC \
        -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/linux" \
        $(pkg-config --cflags quantlib) \
        quantlib_wrap.cpp \
        $(pkg-config --libs quantlib) \
        -o quantlib4j-native-linux/src/main/resources/libquantlib4j.so

    # Build quantlib4j-native-linux
    echo "Building quantlib4j-native-linux..."
    mvn clean install -pl quantlib4j-native-linux -DskipTests

    # Build quantlib4j-loader
    echo "Building quantlib4j-loader..."
    mvn clean install -pl quantlib4j-loader -DskipTests

    echo "OK: Native library built"
else
    echo ""
    echo "[5/5] Skipping native build (--skip-build)"
fi

echo ""
echo "=============================================="
echo "  Build Complete!"
echo "=============================================="
echo ""
echo "Artifacts:"
if [ -f "$WORKSPACE/quantlib4j-java/target/quantlib4j-$PROJECT_VERSION.jar" ]; then
    echo "  Java JAR: $WORKSPACE/quantlib4j-java/target/quantlib4j-$PROJECT_VERSION.jar"
fi
if [ -f "$WORKSPACE/quantlib4j-native-linux/target/quantlib4j-native-linux-$PROJECT_VERSION.jar" ]; then
    echo "  Native JAR: $WORKSPACE/quantlib4j-native-linux/target/quantlib4j-native-linux-$PROJECT_VERSION.jar"
fi
if [ -f "$WORKSPACE/quantlib4j-loader/target/quantlib4j-loader-$PROJECT_VERSION.jar" ]; then
    echo "  Loader JAR: $WORKSPACE/quantlib4j-loader/target/quantlib4j-loader-$PROJECT_VERSION.jar"
fi
