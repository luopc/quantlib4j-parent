#!/bin/bash
# docker-build.sh - Build QuantLib4J using Docker
# Usage: ./docker-build.sh [PLATFORM] [--skip-swig] [--skip-native] [--deploy]
#
# Platforms: linux, windows, macos, all (default: linux)
#
# Examples:
#   ./docker-build.sh linux                    # Build Linux native only
#   ./docker-build.sh all                      # Build all platforms
#   ./docker-build.sh linux --skip-native     # Generate SWIG only
#   ./docker-build.sh linux --deploy         # Build and deploy to Nexus
#
# Requirements:
#   - Docker installed and running
#   - QuantLib-SWIG cloned at ../../QuantLib-SWIG (or specify path)
#
# Environment variables:
#   NEXUS_USER        - Nexus username (required for --deploy)
#   NEXUS_PASS        - Nexus password (required for --deploy)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_VERSION="${PROJECT_VERSION:-1.42.0-SNAPSHOT}"
QUANTLIB_VERSION="${QUANTLIB_VERSION:-1.42}"
JAVA_PACKAGE="com.luopc.platform.quantlib"

# Default values
PLATFORM="linux"
SKIP_SWIG=false
SKIP_NATIVE=false
DEPLOY=false
SWIG_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        linux|windows|macos|all)
            PLATFORM="$1"
            shift
            ;;
        --skip-swig)
            SKIP_SWIG=true
            shift
            ;;
        --skip-native)
            SKIP_NATIVE=true
            shift
            ;;
        --deploy)
            DEPLOY=true
            shift
            ;;
        --swig-dir)
            SWIG_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [PLATFORM] [OPTIONS]"
            echo ""
            echo "Platforms:"
            echo "  linux   - Build Linux native library (default)"
            echo "  windows - Build Windows native library"
            echo "  macos   - Build macOS native library"
            echo "  all     - Build all platforms"
            echo ""
            echo "Options:"
            echo "  --skip-swig    Skip SWIG code generation"
            echo "  --skip-native  Skip native library compilation"
            echo "  --deploy       Deploy to Nexus after build"
            echo "  --swig-dir DIR QuantLib-SWIG directory"
            echo "  --help         Show this help"
            echo ""
            echo "Environment variables:"
            echo "  NEXUS_USER     Nexus username (required for --deploy)"
            echo "  NEXUS_PASS     Nexus password (required for --deploy)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect SWIG_DIR if not specified
if [ -z "$SWIG_DIR" ]; then
    # Look for QuantLib-SWIG in common locations
    if [ -d "$WORKSPACE/../../QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/../../QuantLib-SWIG"
    elif [ -d "$WORKSPACE/../QuantLib-SWIG" ]; then
        SWIG_DIR="$WORKSPACE/../QuantLib-SWIG"
    else
        echo "ERROR: QuantLib-SWIG not found"
        echo "Please specify with --swig-dir or clone to ../../QuantLib-SWIG"
        exit 1
    fi
fi

echo "=============================================="
echo "  QuantLib4J Docker Build"
echo "=============================================="
echo "Platform:       $PLATFORM"
echo "Project Version: $PROJECT_VERSION"
echo "QuantLib Version: $QUANTLIB_VERSION"
echo "SWIG Directory: $SWIG_DIR"
echo "Workspace:      $WORKSPACE"
echo "Skip SWIG:      $SKIP_SWIG"
echo "Skip Native:    $SKIP_NATIVE"
echo "Deploy:         $DEPLOY"
echo "=============================================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. Please install Docker."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running. Please start Docker."
    exit 1
fi

echo "Docker version: $(docker version --format '{{.Server.Version}}')"

# Build Docker image
BUILD_IMAGE="quantlib4j-builder:latest"

echo ""
echo "[1/5] Building Docker build image..."
docker build -f "$WORKSPACE/Dockerfile.build" \
    --build-arg QUANTLIB_VERSION=$QUANTLIB_VERSION \
    -t "$BUILD_IMAGE" \
    "$WORKSPACE" 2>/dev/null || {
    echo "Using pre-existing image or building without cache..."
    docker build -f "$WORKSPACE/Dockerfile.build" \
        --build-arg QUANTLIB_VERSION=$QUANTLIB_VERSION \
        --no-cache \
        -t "$BUILD_IMAGE" \
        "$WORKSPACE"
}

echo "  ✓ Build image ready: $BUILD_IMAGE"

# Step 2: Generate SWIG Java code
if [ "$SKIP_SWIG" = true ]; then
    echo ""
    echo "[2/5] Skipping SWIG generation (--skip-swig)"
else
    echo ""
    echo "[2/5] Generating SWIG Java code..."
    JAVA_SRC_DIR="$WORKSPACE/quantlib4j-java/src/main/java"

    docker run --rm \
        -v "$SWIG_DIR:/workspace/QuantLib-SWIG:ro" \
        -v "$WORKSPACE:/workspace" \
        -w /workspace \
        "$BUILD_IMAGE" \
        bash -c "
            cd /workspace/QuantLib-SWIG/SWIG
            swig -c++ -java \
                -package $JAVA_PACKAGE \
                -outdir /workspace/quantlib4j-java/src/main/java \
                -o quantlib_wrap.cpp \
                quantlib.i

            echo 'Generated files:'
            find /workspace/quantlib4j-java/src/main/java -name '*.java' | wc -l
        "

    echo "  ✓ SWIG Java code generated"
fi

# Step 3: Build Java module
echo ""
echo "[3/5] Building Java module..."
cd "$WORKSPACE"

mvn clean install -pl quantlib4j-java -DskipTests -q
echo "  ✓ Java JAR built: quantlib4j-java/target/quantlib4j-${PROJECT_VERSION}.jar"

# Step 4: Build native libraries
if [ "$SKIP_NATIVE" = true ]; then
    echo ""
    echo "[4/5] Skipping native build (--skip-native)"
else
    echo ""
    echo "[4/5] Building native libraries..."

    build_platform() {
        local plat=$1
        local dockerfile=$2
        local src_dir=$3
        local output_name=$4
        local native_module=$5

        echo ""
        echo "  Building $plat native library..."

        # Build platform-specific Docker image
        local plat_image="quantlib4j-builder-${plat}:latest"
        docker build -f "$dockerfile" \
            -t "$plat_image" \
            "$WORKSPACE" 2>/dev/null || true

        # Build native library
        case "$plat" in
            linux)
                docker run --rm \
                    -v "$SWIG_DIR:/workspace/QuantLib-SWIG:ro" \
                    -v "$WORKSPACE:/workspace" \
                    -w /workspace \
                    "$plat_image" \
                    bash -c "
                        cd /workspace/QuantLib-SWIG/SWIG
                        g++ -shared -fPIC \
                            -I\${JAVA_HOME}/include -I\${JAVA_HOME}/include/linux \
                            \$(pkg-config --cflags quantlib) \
                            quantlib_wrap.cpp \
                            \$(pkg-config --libs quantlib) \
                            -o libquantlib4j.so

                        cp libquantlib4j.so /workspace/${src_dir}/
                    "
                ;;
            macos)
                echo "    ⚠ macOS build requires macOS Docker host"
                ;;
            windows)
                echo "    ⚠ Windows build requires Windows Docker host"
                ;;
        esac

        # Build native JAR
        if [ -f "$WORKSPACE/${src_dir}/libquantlib4j.so" ] || \
           [ -f "$WORKSPACE/${src_dir}/quantlib4j.dll" ] || \
           [ -f "$WORKSPACE/${src_dir}/libquantlib4j.dylib" ]; then
            mvn clean install -pl "$native_module" -DskipTests -q
            echo "    ✓ $plat native JAR built"
        fi
    }

    case "$PLATFORM" in
        linux)
            build_platform "linux" \
                "$WORKSPACE/quantlib4j-native-linux/Dockerfile" \
                "quantlib4j-native-linux/src/main/resources" \
                "libquantlib4j.so" \
                "quantlib4j-native-linux"
            ;;
        windows)
            build_platform "windows" \
                "$WORKSPACE/quantlib4j-native-windows/Dockerfile" \
                "quantlib4j-native-windows/src/main/resources" \
                "quantlib4j.dll" \
                "quantlib4j-native-windows"
            ;;
        macos)
            build_platform "macos" \
                "$WORKSPACE/quantlib4j-native-macos/Dockerfile" \
                "quantlib4j-native-macos/src/main/resources" \
                "libquantlib4j.dylib" \
                "quantlib4j-native-macos"
            ;;
        all)
            build_platform "linux" \
                "$WORKSPACE/quantlib4j-native-linux/Dockerfile" \
                "quantlib4j-native-linux/src/main/resources" \
                "libquantlib4j.so" \
                "quantlib4j-native-linux"
            ;;
    esac
fi

# Step 5: Build loader module
echo ""
echo "[5/5] Building loader module..."
mvn clean install -pl quantlib4j-loader -DskipTests -q
echo "  ✓ Loader JAR built"

# Step 6: Deploy to Nexus
if [ "$DEPLOY" = true ]; then
    echo ""
    echo "[Deploy] Publishing to Nexus..."

    if [ -z "$NEXUS_USER" ] || [ -z "$NEXUS_PASS" ]; then
        echo "ERROR: NEXUS_USER and NEXUS_PASS must be set for --deploy"
        exit 1
    fi

    # Create Maven settings
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

    cd "$WORKSPACE/quantlib4j-parent"
    mvn deploy -DskipTests -s "$SETTINGS_FILE" -P release

    rm -f "$SETTINGS_FILE"

    echo ""
    echo "  ✓ Deployed to Nexus"
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
echo "Next steps:"
echo "  1. Install to local Maven: mvn install -pl quantlib4j-java,quantlib4j-loader"
echo "  2. Add dependency to valuation-service pom.xml"
