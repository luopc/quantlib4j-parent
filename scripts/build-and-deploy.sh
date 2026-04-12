#!/bin/bash
# build-and-deploy.sh - Build QuantLib4J and deploy to Nexus
# Usage: ./build-and-deploy.sh [SWIG_DIR] [--skip-native] [--platform PLATFORM]
#
# Environment variables:
#   NEXUS_USER - Nexus username
#   NEXUS_PASS - Nexus password
#   QUANTLIB_VERSION - QuantLib version (default: 1.34)
#
# Examples:
#   ./build-and-deploy.sh /path/to/QuantLib-SWIG
#   ./build-and-deploy.sh /path/to/QuantLib-SWIG --platform linux
#   ./build-and-deploy.sh /path/to/QuantLib-SWIG --skip-native

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
QUANTLIB_VERSION="${QUANTLIB_VERSION:-1.34}"
PROJECT_VERSION="${PROJECT_VERSION:-1.3.5-SNAPSHOT}"
JAVA_PACKAGE="com.luopc.platform.quantlib"

# Default paths
SWIG_DIR="${1:-$WORKSPACE/../../QuantLib-SWIG}"
SKIP_NATIVE=false
PLATFORM=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-native)
            SKIP_NATIVE=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [SWIG_DIR] [--skip-native] [--platform PLATFORM]"
            echo ""
            echo "Options:"
            echo "  --skip-native    Skip native library compilation"
            echo "  --platform       Target platform: linux, windows, macos (default: all)"
            echo "  --help          Show this help"
            echo ""
            echo "Environment variables:"
            echo "  NEXUS_USER      Nexus username"
            echo "  NEXUS_PASS      Nexus password"
            echo "  QUANTLIB_VERSION QuantLib version (default: 1.34)"
            echo "  PROJECT_VERSION  Project version (default: 1.3.5-SNAPSHOT)"
            exit 0
            ;;
        *)
            SWIG_DIR="$1"
            shift
            ;;
    esac
done

echo "=============================================="
echo "  QuantLib4J Build & Deploy Script"
echo "=============================================="
echo "Project Version:  $PROJECT_VERSION"
echo "QuantLib Version: $QUANTLIB_VERSION"
echo "Java Package:     $JAVA_PACKAGE"
echo "SWIG Directory:  $SWIG_DIR"
echo "Workspace:       $WORKSPACE"
echo "Skip Native:     $SKIP_NATIVE"
echo "Platform:        ${PLATFORM:-all}"
echo "=============================================="

# Check prerequisites
echo ""
echo "[1/6] Checking prerequisites..."

if ! command -v java &> /dev/null; then
    echo "ERROR: Java not found. Please install JDK 21+"
    exit 1
fi
echo "  ✓ Java: $(java -version 2>&1 | head -n1)"

if ! command -v mvn &> /dev/null; then
    echo "ERROR: Maven not found. Please install Maven 3.9+"
    exit 1
fi
echo "  ✓ Maven: $(mvn -version | head -n1)"

if ! command -v swig &> /dev/null; then
    echo "ERROR: SWIG not found. Please install SWIG 4.2+"
    exit 1
fi
echo "  ✓ SWIG: $(swig -version | head -n2 | tail -n1)"

# Check QuantLib-SWIG
if [ ! -d "$SWIG_DIR" ]; then
    echo "ERROR: QuantLib-SWIG not found at: $SWIG_DIR"
    echo "Please specify the path: $0 /path/to/QuantLib-SWIG"
    exit 1
fi

if [ ! -f "$SWIG_DIR/SWIG/quantlib.i" ]; then
    echo "ERROR: quantlib.i not found in $SWIG_DIR/SWIG/"
    exit 1
fi
echo "  ✓ QuantLib-SWIG: $SWIG_DIR"

# Check QuantLib library for native builds
if [ "$SKIP_NATIVE" = false ]; then
    if pkg-config --exists quantlib 2>/dev/null; then
        echo "  ✓ QuantLib: $(pkg-config --modversion quantlib)"
    else
        echo "  ⚠ Warning: QuantLib dev library not found. Native build may fail."
        echo "    Install with: apt-get install libquantlib-dev"
    fi
fi

# Check Nexus credentials
if [ -z "$NEXUS_USER" ] || [ -z "$NEXUS_PASS" ]; then
    echo ""
    echo "WARNING: NEXUS_USER or NEXUS_PASS not set."
    echo "Build will proceed but deploy will be skipped."
    echo "Set credentials with:"
    echo "  export NEXUS_USER=your_username"
    echo "  export NEXUS_PASS=your_password"
    DO_DEPLOY=false
else
    DO_DEPLOY=true
fi

# Create Maven settings if deploying
MavenSettings="$WORKSPACE/settings.xml"
if [ "$DO_DEPLOY" = true ]; then
    echo ""
    echo "[2/6] Configuring Maven settings..."

    cat > "$MavenSettings" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings>
    <servers>
        <server>
            <id>deploy-release</id>
            <username>${NEXUS_USER}</username>
            <password>${NEXUS_PASS}</password>
        </server>
        <server>
            <id>deploy-snapshot</id>
            <username>${NEXUS_USER}</username>
            <password>${NEXUS_PASS}</password>
        </server>
    </servers>
</settings>
EOF
    echo "  ✓ Maven settings created: $MavenSettings"
fi

# Step 1: Generate SWIG Java code
echo ""
echo "[3/6] Generating SWIG Java code..."
JAVA_SRC_DIR="$WORKSPACE/quantlib4j-java/src/main/java"

mkdir -p "$JAVA_SRC_DIR"
cd "$SWIG_DIR/SWIG"

swig -c++ -java \
    -package "$JAVA_PACKAGE" \
    -outdir "$JAVA_SRC_DIR" \
    -o quantlib_wrap.cpp \
    quantlib.i

JAVA_FILE_COUNT=$(find "$JAVA_SRC_DIR" -name "*.java" 2>/dev/null | wc -l)
echo "  ✓ Generated $JAVA_FILE_COUNT Java files"

# Step 2: Build Java module
echo ""
echo "[4/6] Building Java module..."
cd "$WORKSPACE"

mvn clean install -pl quantlib4j-java \
    -DskipTests \
    -q

echo "  ✓ Java JAR built: quantlib4j-java/target/quantlib4j-${PROJECT_VERSION}.jar"

# Step 3: Build native libraries (if not skipped)
if [ "$SKIP_NATIVE" = false ]; then
    echo ""
    echo "[5/6] Building native libraries..."

    cd "$SWIG_DIR/SWIG"

    # Detect current platform
    CURRENT_PLATFORM=""
    case "$(uname -s)" in
        Linux*)     CURRENT_PLATFORM="linux" ;;
        Darwin*)    CURRENT_PLATFORM="macos" ;;
        MINGW*|MSYS*) CURRENT_PLATFORM="windows" ;;
    esac

    # Determine which platforms to build
    PLATFORMS_TO_BUILD=()
    if [ -z "$PLATFORM" ]; then
        PLATFORMS_TO_BUILD=("$CURRENT_PLATFORM")
    else
        PLATFORMS_TO_BUILD=("$PLATFORM")
    fi

    for plat in "${PLATFORMS_TO_BUILD[@]}"; do
        echo ""
        echo "  Building native library for: $plat"

        case "$plat" in
            linux)
                if [ "$CURRENT_PLATFORM" != "linux" ]; then
                    echo "    ⚠ Skipping: Linux build requires Linux environment"
                    continue
                fi

                g++ -shared -fPIC \
                    -I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux \
                    $(pkg-config --cflags quantlib) \
                    quantlib_wrap.cpp \
                    $(pkg-config --libs quantlib) \
                    -o libquantlib4j.so

                cp libquantlib4j.so "$WORKSPACE/quantlib4j-native-linux/src/main/resources/"
                echo "    ✓ Linux native library built"

                mvn clean install -pl quantlib4j-native-linux \
                    -DskipTests -q
                echo "    ✓ Linux native JAR deployed"
                ;;
            macos)
                if [ "$CURRENT_PLATFORM" != "macos" ]; then
                    echo "    ⚠ Skipping: macOS build requires macOS environment"
                    continue
                fi

                g++ -dynamiclib \
                    -I${JAVA_HOME}/include -I${JAVA_HOME}/include/darwin \
                    quantlib_wrap.cpp \
                    $(pkg-config --libs quantlib) \
                    -o libquantlib4j.dylib \
                    -current_version ${QUANTLIB_VERSION}.0

                cp libquantlib4j.dylib "$WORKSPACE/quantlib4j-native-macos/src/main/resources/"
                echo "    ✓ macOS native library built"

                mvn clean install -pl quantlib4j-native-macos \
                    -DskipTests -q
                echo "    ✓ macOS native JAR deployed"
                ;;
            windows)
                echo "    ⚠ Windows native build requires Windows environment"
                echo "    Use the build-native.bat script on Windows"
                ;;
        esac
    done
else
    echo ""
    echo "[5/6] Skipping native library build (--skip-native)"
fi

# Step 4: Build loader module
echo ""
echo "[6/6] Building loader module..."
cd "$WORKSPACE"

mvn clean install -pl quantlib4j-loader \
    -DskipTests -q

echo "  ✓ Loader JAR built"

# Step 5: Deploy to Nexus
echo ""
echo "=============================================="
echo "[Deploy] Publishing to Nexus"
echo "=============================================="

if [ "$DO_DEPLOY" = false ]; then
    echo "⚠ Skipping deploy (credentials not set)"
else
    # Deploy to Nexus
    if [[ "$PROJECT_VERSION" == *"SNAPSHOT"* ]]; then
        DEPLOY_URL="$WORKSPACE/quantlib4j-parent"
    else
        DEPLOY_URL="$WORKSPACE/quantlib4j-parent"
    fi

    cd "$WORKSPACE/quantlib4j-parent"

    echo "Deploying artifacts..."
    mvn deploy -DskipTests \
        -s "$MavenSettings" \
        -P release

    echo ""
    echo "=============================================="
    echo "  Deploy Complete!"
    echo "=============================================="
    echo ""
    echo "Artifacts deployed to Nexus:"
    echo "  https://lb.luopc.com/nexus/"
    echo ""
    echo "Maven dependency:"
    echo "  <dependency>"
    echo "    <groupId>com.luopc.platform.quantlib</groupId>"
    echo "    <artifactId>quantlib4j</artifactId>"
    echo "    <version>$PROJECT_VERSION</version>"
    echo "  </dependency>"
fi

# Cleanup
if [ -f "$MavenSettings" ]; then
    rm -f "$MavenSettings"
fi

echo ""
echo "Build complete!"
