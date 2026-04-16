#!/bin/bash
# quick-build.sh - QuantLib4J 快速构建脚本
# Usage: ./quick-build.sh [QuantLib-SWIG-path]
#
# 示例:
#   ./quick-build.sh                          # 使用默认路径
#   ./quick-build.sh /path/to/QuantLib-SWIG  # 指定路径

set -e

# 配置
VERSION="1.34"
PACKAGE="com.luopc.platform.quantlib"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(dirname "$SCRIPT_DIR")"

# QuantLib-SWIG 路径
QUANTLIB_SWIG="${1:-$WORKSPACE/../../QuantLib-SWIG}"
if [ ! -d "$QUANTLIB_SWIG" ]; then
    echo "❌ QuantLib-SWIG not found at: $QUANTLIB_SWIG"
    echo "   Please specify path: $0 /path/to/QuantLib-SWIG"
    exit 1
fi

# 输出目录
QUANTLIB4J="$WORKSPACE"
JAVA_SRC="$QUANTLIB4J/quantlib4j-java/src/main/java"
JAVA_TARGET="$QUANTLIB4J/quantlib4j-java/target"

echo "========================================"
echo "  QuantLib4J Quick Build Script"
echo "========================================"
echo "Version:        $VERSION"
echo "Package:        $PACKAGE"
echo "SWIG Source:    $QUANTLIB_SWIG"
echo "Output:         $JAVA_TARGET"
echo ""

# 检查依赖
check_dependency() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1: $(command -v $1)"
    else
        echo "❌ $1 not found - please install"
        exit 1
    fi
}

echo ">>> Checking dependencies..."
check_dependency swig
check_dependency javac
check_dependency jar
check_dependency g++
echo ""

# 1. 清理
echo ">>> Step 1: Clean previous build"
rm -rf "$JAVA_SRC"/*.{java,h}
rm -rf "$JAVA_TARGET"
mkdir -p "$JAVA_SRC"
mkdir -p "$JAVA_TARGET"
echo "✅ Cleaned"
echo ""

# 2. SWIG 生成
echo ">>> Step 2: Generate Java code from SWIG"
cd "$QUANTLIB_SWIG/SWIG"
swig -c++ -java \
    -package "$PACKAGE" \
    -outdir "$JAVA_SRC" \
    -o quantlib_wrap.cpp \
    quantlib.i

JAVA_COUNT=$(find "$JAVA_SRC" -name "*.java" 2>/dev/null | wc -l)
echo "✅ Generated $JAVA_COUNT Java files"
echo ""

# 3. 编译 Java
echo ">>> Step 3: Compile Java"
cd "$JAVA_TARGET"
mkdir -p classes
find "$JAVA_SRC" -name "*.java" > sources.txt
javac -d classes @sources.txt
jar cf "quantlib4j-$VERSION.jar" -C classes com
echo "✅ Java JAR created: quantlib4j-$VERSION.jar"
echo ""

# 4. 编译原生库 (Linux)
echo ">>> Step 4: Compile native library (Linux)"
cd "$QUANTLIB_SWIG/Java"

if pkg-config --exists quantlib; then
    echo "   Using system QuantLib"
    CFLAGS=$(pkg-config --cflags quantlib)
    LIBS=$(pkg-config --libs quantlib)
else
    echo "   ⚠️  QuantLib not found via pkg-config"
    echo "   Skipping native compilation"
    echo ""
    echo "========================================"
    echo "  Build Summary"
    echo "========================================"
    echo "✅ Java code generated: $JAVA_COUNT files"
    echo "✅ Java JAR created:    quantlib4j-$VERSION.jar"
    echo "❌ Native library:      Skipped (QuantLib not installed)"
    echo ""
    echo "To install QuantLib:"
    echo "  Ubuntu/Debian: sudo apt-get install libquantlib-dev"
    echo "  macOS:         brew install quantlib"
    echo ""
    echo "To continue native build after installing QuantLib:"
    echo "  cd $QUANTLIB_SWIG/Java"
    echo "  g++ -c -fPIC \\"
    echo "      -I\\\${JAVA_HOME}/include -I\\\${JAVA_HOME}/include/linux \\"
    echo "      quantlib_wrap.cpp -o quantlib_wrap.o"
    echo "  g++ -shared -fPIC quantlib_wrap.o \\"
    echo "      \$(pkg-config --libs quantlib) -o libquantlib4j.so"
    exit 0
fi

g++ -c -fPIC \
    -I${JAVA_HOME}/include \
    -I${JAVA_HOME}/include/linux \
    $CFLAGS \
    quantlib_wrap.cpp -o quantlib_wrap.o

g++ -shared -fPIC quantlib_wrap.o $LIBS -o libquantlib4j.so

if [ -f libquantlib4j.so ]; then
    echo "✅ Native library created: libquantlib4j.so"
else
    echo "❌ Native library compilation failed"
    exit 1
fi
echo ""

# 5. 打包 Native JAR
echo ">>> Step 5: Package native JAR"
cp libquantlib4j.so "$JAVA_TARGET/"
cd "$JAVA_TARGET"
jar cf "quantlib4j-$VERSION-linux-x64.jar" libquantlib4j.so
echo "✅ Native JAR created: quantlib4j-$VERSION-linux-x64.jar"
echo ""

# 6. 安装到本地 Maven
echo ">>> Step 6: Install to local Maven repository"
cd "$JAVA_TARGET"
mvn install:install-file \
    -Dfile="$JAVA_TARGET/quantlib4j-$VERSION.jar" \
    -DgroupId=com.luopc.platform.quantlib \
    -DartifactId=quantlib4j \
    -Dversion=$VERSION \
    -Dpackaging=jar 2>/dev/null || true

mvn install:install-file \
    -Dfile="$JAVA_TARGET/quantlib4j-$VERSION-linux-x64.jar" \
    -DgroupId=com.luopc.platform.quantlib \
    -DartifactId=quantlib4j \
    -Dversion=$VERSION \
    -Dpackaging=jar \
    -Dclassifier=linux-x64 2>/dev/null || true
echo "✅ Installed to local Maven"
echo ""

# 清理
rm -f "$JAVA_TARGET"/sources.txt
rm -f "$QUANTLIB_SWIG/SWIG/quantlib_wrap.cpp" "$QUANTLIB_SWIG/SWIG/quantlib_wrap.o"

echo "========================================"
echo "  Build Complete!"
echo "========================================"
echo "Artifacts:"
ls -lh "$JAVA_TARGET"/*.jar
echo ""
echo "Maven dependency:"
echo "  <dependency>"
echo "    <groupId>com.luopc.platform.quantlib</groupId>"
echo "    <artifactId>quantlib4j</artifactId>"
echo "    <version>$VERSION</version>"
echo "  </dependency>"
