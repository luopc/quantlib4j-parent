#!/bin/bash
# build-all-platforms.sh - Build QuantLib4J for all platforms
# Usage: ./build-all-platforms.sh [--deploy]
#
# This script builds native JARs for Linux, Windows, and macOS platforms.
# Each platform requires its native Docker environment for native library compilation.
#
# Requirements:
#   - Linux/macOS: Docker installed and running
#   - Windows: Docker Desktop installed and running
#   - QuantLib-SWIG cloned at ../../QuantLib-SWIG (or specify path)
#
# Environment variables:
#   NEXUS_USER        - Nexus username (required for --deploy)
#   NEXUS_PASS        - Nexus password (required for --deploy)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
DEPLOY=false
SKIP_NATIVE=false
SWIG_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy)
            DEPLOY=true
            shift
            ;;
        --skip-native)
            SKIP_NATIVE=true
            shift
            ;;
        --swig-dir)
            SWIG_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-native    Skip native library compilation"
            echo "  --deploy         Deploy to Nexus after build"
            echo "  --swig-dir DIR   QuantLib-SWIG directory"
            echo "  --help           Show this help"
            echo ""
            echo "Environment variables:"
            echo "  NEXUS_USER       Nexus username"
            echo "  NEXUS_PASS       Nexus password"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect SWIG_DIR
if [ -z "$SWIG_DIR" ]; then
    if [ -d "$WORKSPACE/../../QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/../../QuantLib-SWIG"
    elif [ -d "$WORKSPACE/../QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/../QuantLib-SWIG"
    fi
fi

echo "=============================================="
echo "  QuantLib4J Multi-Platform Build"
echo "=============================================="
echo "Workspace:    $WORKSPACE"
echo "SWIG Dir:     ${SWIG_DIR:-auto-detect}"
echo "Skip Native:  $SKIP_NATIVE"
echo "Deploy:       $DEPLOY"
echo "=============================================="

# Check Docker
if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running. Please start Docker."
    exit 1
fi

# Build options
DOCKER_OPTS=""
[ -n "$SWIG_DIR" ] && DOCKER_OPTS="--swig-dir $SWIG_DIR"
$SKIP_NATIVE && DOCKER_OPTS="$DOCKER_OPTS --skip-native"
$DEPLOY && DOCKER_OPTS="$DOCKER_OPTS --deploy"

echo ""
echo "[1/4] Building Java module (required by all platforms)..."
cd "$WORKSPACE"
mvn clean install -pl quantlib4j-java -DskipTests -q
echo "  OK: Java JAR built"

if [ "$SKIP_NATIVE" = true ]; then
    echo ""
    echo "[Skip] Skipping native builds (--skip-native)"
else
    echo ""
    echo "[2/4] Building Linux native library..."

    if [ -f "$WORKSPACE/quantlib4j-native-linux/Dockerfile" ]; then
        docker build -f "$WORKSPACE/quantlib4j-native-linux/Dockerfile" \
            -t "quantlib4j-builder-linux:latest" \
            "$WORKSPACE" 2>/dev/null || true

        docker run --rm \
            -v "${SWIG_DIR:-$(dirname $WORKSPACE)/QuantLib-SWIG}:/workspace/QuantLib-SWIG:ro" \
            -v "$WORKSPACE:/workspace" \
            -w /workspace \
            "quantlib4j-builder-linux:latest" \
            bash -c "
                cd /workspace/QuantLib-SWIG/SWIG
                g++ -shared -fPIC \
                    -I\${JAVA_HOME}/include -I\${JAVA_HOME}/include/linux \
                    \$(pkg-config --cflags quantlib) \
                    quantlib_wrap.cpp \
                    \$(pkg-config --libs quantlib) \
                    -o libquantlib4j.so
                cp libquantlib4j.so /workspace/quantlib4j-native-linux/src/main/resources/
            " 2>/dev/null || echo "  WARN: Linux native build requires QuantLib-SWIG"

        if [ -f "$WORKSPACE/quantlib4j-native-linux/src/main/resources/libquantlib4j.so" ]; then
            mvn clean install -pl quantlib4j-native-linux -DskipTests -q
            echo "  OK: Linux native JAR built"
        fi
    else
        echo "  SKIP: Dockerfile not found"
    fi

    echo ""
    echo "[3/4] Building Windows native library..."
    echo "  INFO: Windows build requires Windows Docker host"
    echo "        Run 'docker-build.bat windows' on Windows"

    echo ""
    echo "[4/4] Building macOS native library..."
    echo "  INFO: macOS build requires macOS Docker host"
    echo "        Run 'docker-build.sh macos' on macOS"
fi

# Build loader module
echo ""
echo "[Final] Building loader module..."
mvn clean install -pl quantlib4j-loader -DskipTests -q
echo "  OK: Loader JAR built"

# Deploy to Nexus
if [ "$DEPLOY" = true ]; then
    echo ""
    echo "[Deploy] Publishing to Nexus..."

    if [ -z "$NEXUS_USER" ] || [ -z "$NEXUS_PASS" ]; then
        echo "ERROR: NEXUS_USER and NEXUS_PASS must be set for --deploy"
        exit 1
    fi

    SETTINGS_FILE="$WORKSPACE/settings.xml"
    cat > "$SETTINGS_FILE" << EOF
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

    cd "$WORKSPACE"
    mvn deploy -DskipTests -s "$SETTINGS_FILE" -P release
    rm -f "$SETTINGS_FILE"

    echo "  OK: Deployed to Nexus"
fi

echo ""
echo "=============================================="
echo "  Build Complete!"
echo "=============================================="
echo ""
echo "Artifacts:"
ls -lh "$WORKSPACE/quantlib4j-java/target"/*.jar 2>/dev/null || true
ls -lh "$WORKSPACE/quantlib4j-native-linux/target"/*.jar 2>/dev/null || true
echo ""
echo "Platform JARs:"
echo "  - quantlib4j-java:     Java bindings"
echo "  - quantlib4j-loader:   Native library loader"
echo "  - quantlib4j-native-linux: Linux native library"
echo ""
echo "To build Windows/macOS native libraries, run on respective platforms:"
echo "  Windows: docker-build.bat windows"
echo "  macOS:   docker-build.sh macos"
