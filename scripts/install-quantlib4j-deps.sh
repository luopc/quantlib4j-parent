#!/bin/bash
#
# install-quantlib4j-deps.sh
# Install dependencies for QuantLib4J build on AlmaLinux 9
#
# Usage:
#   ./install-quantlib4j-deps.sh          # Install all dependencies
#   ./install-quantlib4j-deps.sh --verify # Verify installation only
#
# Author: Claude
# Date: 2026-04-11

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Please run as root: sudo $0"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION_ID="${VERSION_ID:-unknown}"
    else
        log_error "Cannot detect OS"
        exit 1
    fi

    case "$OS_ID" in
        almalinux|almalinuxos|rhel|centos|rocky)
            PKG_MANAGER="dnf"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            ;;
        debian|ubuntu)
            PKG_MANAGER="apt-get"
            ;;
        *)
            log_error "Unsupported OS: $OS_ID"
            exit 1
            ;;
    esac

    log_info "Detected OS: $OS_ID $OS_VERSION_ID (package manager: $PKG_MANAGER)"
}

# Check Java
check_java() {
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n1 | awk -F'"' '{print $2}')
        JAVA_HOME="${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))}"
        log_info "Java: $JAVA_VERSION"
        log_info "JAVA_HOME: $JAVA_HOME"
    else
        log_error "Java not found. Please install JDK 21+"
        exit 1
    fi

    # Check version
    if command -v java &> /dev/null; then
        JAVA_MAJOR=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$JAVA_MAJOR" -lt 21 ]]; then
            log_warn "Java 21+ recommended, found Java $JAVA_MAJOR"
        fi
    fi
}

# Check Maven
check_maven() {
    if command -v mvn &> /dev/null; then
        MVN_VERSION=$(mvn -version | head -n1 | awk '{print $3}')
        log_info "Maven: $MVN_VERSION"
    else
        log_error "Maven not found. Please install Maven 3.9+"
        exit 1
    fi
}

# Install EPEL for RHEL-based systems
install_epel() {
    if [[ "$PKG_MANAGER" == "dnf" ]] && ! rpm -q epel-release &> /dev/null; then
        log_info "Installing EPEL repository..."
        dnf install -y epel-release
    fi
}

# Install SWIG
install_swig() {
    if command -v swig &> /dev/null; then
        SWIG_VERSION=$(swig -version | head -n1 | awk '{print $3}')
        log_info "SWIG already installed: $SWIG_VERSION"
        return 0
    fi

    log_info "Installing SWIG..."

    case "$PKG_MANAGER" in
        dnf)
            dnf install -y swig
            ;;
        apt-get)
            apt-get update && apt-get install -y swig
            ;;
    esac

    if command -v swig &> /dev/null; then
        SWIG_VERSION=$(swig -version | head -n1 | awk '{print $3}')
        log_info "SWIG installed: $SWIG_VERSION"
    else
        log_error "SWIG installation failed"
        return 1
    fi
}

# Install QuantLib from package manager
install_quantlib_pkg() {
    if pkg-config --exists quantlib 2>/dev/null; then
        QL_VERSION=$(pkg-config --modversion quantlib)
        log_info "QuantLib already installed: $QL_VERSION"
        return 0
    fi

    log_info "Installing QuantLib from package manager..."

    case "$PKG_MANAGER" in
        dnf)
            dnf install -y quantlib-devel
            ;;
        apt-get)
            apt-get update && apt-get install -y libquantlib-dev
            ;;
    esac

    if pkg-config --exists quantlib 2>/dev/null; then
        QL_VERSION=$(pkg-config --modversion quantlib)
        log_info "QuantLib installed: $QL_VERSION"
    else
        log_warn "Package installation failed, will try from source"
        return 1
    fi
}

# Install QuantLib from source
install_quantlib_source() {
    local VERSION="${1:-1.34}"
    local INSTALL_DIR="${2:-/usr/local}"

    log_info "Installing QuantLib $VERSION from source..."

    # Install build dependencies
    log_info "Installing build dependencies..."

    case "$PKG_MANAGER" in
        dnf)
            dnf install -y \
                cmake \
                gcc-c++ \
                make \
                boost-devel \
                wget
            ;;
        apt-get)
            apt-get update && apt-get install -y \
                cmake \
                g++ \
                make \
                libboost-all-dev \
                wget
            ;;
    esac

    # Download
    local SRC_DIR="/tmp/QuantLib-$VERSION"
    if [[ ! -d "$SRC_DIR" ]]; then
        log_info "Downloading QuantLib $VERSION..."
        cd /tmp
        wget -q https://github.com/lballabio/QuantLib/releases/download/QuantLib-v${VERSION}/QuantLib-${VERSION}.tar.gz
        tar -xzf QuantLib-${VERSION}.tar.gz
    fi

    # Configure and build
    log_info "Building QuantLib..."
    cd "$SRC_DIR"

    ./configure \
        --enable-thread-safe-observer-pattern \
        --prefix="$INSTALL_DIR"

    make -j$(nproc)
    make install

    # Update library cache
    ldconfig

    # Verify
    if pkg-config --exists quantlib 2>/dev/null; then
        QL_VERSION=$(pkg-config --modversion quantlib)
        log_info "QuantLib installed: $QL_VERSION"
    else
        log_error "QuantLib installation failed"
        return 1
    fi
}

# Install CMake (if needed)
install_cmake() {
    if command -v cmake &> /dev/null; then
        CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
        log_info "CMake already installed: $CMAKE_VERSION"
        return 0
    fi

    log_info "Installing CMake..."

    case "$PKG_MANAGER" in
        dnf)
            dnf install -y cmake
            ;;
        apt-get)
            apt-get update && apt-get install -y cmake
            ;;
    esac
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    local all_ok=true

    # Java
    if command -v java &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Java: $(java -version 2>&1 | head -n1)"
    else
        echo -e "  ${RED}✗${NC} Java: not found"
        all_ok=false
    fi

    # Maven
    if command -v mvn &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Maven: $(mvn -version | head -n1 | awk '{print $3}')"
    else
        echo -e "  ${RED}✗${NC} Maven: not found"
        all_ok=false
    fi

    # SWIG
    if command -v swig &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} SWIG: $(swig -version | head -n1)"
    else
        echo -e "  ${RED}✗${NC} SWIG: not found"
        all_ok=false
    fi

    # CMake
    if command -v cmake &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} CMake: $(cmake --version | head -n1)"
    else
        echo -e "  ${RED}✗${NC} CMake: not found"
        all_ok=false
    fi

    # QuantLib
    if pkg-config --exists quantlib 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} QuantLib: $(pkg-config --modversion quantlib)"
    else
        echo -e "  ${RED}✗${NC} QuantLib: not found"
        all_ok=false
    fi

    echo ""

    if $all_ok; then
        log_info "All dependencies installed successfully!"
        return 0
    else
        log_error "Some dependencies are missing"
        return 1
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install dependencies for QuantLib4J build on AlmaLinux 9 / RHEL 9

OPTIONS:
    --verify         Verify installation only
    --from-source    Install QuantLib from source (default: package manager)
    --version VER    QuantLib version to install from source (default: 1.34)
    --help           Show this help message

EXAMPLES:
    $0                          # Install all dependencies
    $0 --verify                 # Verify installation
    $0 --from-source --version 1.34  # Install specific version from source

EOF
}

# Main
main() {
    local install_method="package"
    local quantlib_version="1.34"
    local verify_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verify)
                verify_only=true
                shift
                ;;
            --from-source)
                install_method="source"
                shift
                ;;
            --version)
                quantlib_version="$2"
                install_method="source"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if $verify_only; then
        detect_os
        check_java
        check_maven
        verify_installation
        exit $?
    fi

    check_root
    detect_os
    check_java
    check_maven

    # Install EPEL for RHEL-based
    install_epel

    # Install CMake
    install_cmake

    # Install SWIG
    install_swig

    # Install QuantLib
    if [[ "$install_method" == "source" ]]; then
        install_quantlib_source "$quantlib_version"
    else
        if ! install_quantlib_pkg; then
            log_warn "Package installation failed, trying from source..."
            install_quantlib_source "$quantlib_version"
        fi
    fi

    # Final verification
    echo ""
    verify_installation
}

main "$@"
