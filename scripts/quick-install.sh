#!/bin/bash
#
# quick-install.sh - One-line QuantLib4J dependency installer
#
# Usage (as root):
#   curl -sL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/quick-install.sh | sudo bash -
#
# Or download and run:
#   wget -qO- https://raw.githubusercontent.com/YOUR_REPO/main/scripts/quick-install.sh | sudo bash -
#
# Author: Claude
# Date: 2026-04-11

set -euo pipefail

echo "=== QuantLib4J Dependency Installer ==="
echo ""

# Detect package manager
if command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
elif command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
else
    echo "ERROR: No supported package manager found"
    exit 1
fi

echo "Detected package manager: $PKG_MANAGER"

# Update package list
echo ""
echo ">>> Updating package list..."
if [[ "$PKG_MANAGER" == "apt-get" ]]; then
    apt-get update -qq
fi

# Install EPEL for RHEL-based systems
if [[ "$PKG_MANAGER" =~ ^(dnf|yum)$ ]] && ! rpm -q epel-release &> /dev/null; then
    echo ">>> Installing EPEL repository..."
    dnf install -y epel-release || yum install -y epel-release
fi

# Install packages
echo ""
echo ">>> Installing dependencies..."

if [[ "$PKG_MANAGER" == "apt-get" ]]; then
    apt-get install -y \
        openjdk-21-jdk \
        maven \
        swig \
        cmake \
        g++ \
        make \
        libquantlib-dev \
        wget
else
    dnf install -y \
        java-21-openjdk-devel \
        maven \
        swig \
        cmake \
        gcc-c++ \
        make \
        quantlib-devel \
        wget || \
    yum install -y \
        java-21-openjdk-devel \
        maven \
        swig \
        cmake \
        gcc-c++ \
        make \
        quantlib-devel \
        wget
fi

# Verify
echo ""
echo "=== Verification ==="
echo ""

verify_cmd() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" &> /dev/null || [[ "$cmd" == "pkg-config" ]]; then
        if [[ "$cmd" == "pkg-config" ]]; then
            if pkg-config --exists quantlib 2>/dev/null; then
                echo "✓ $desc: $(pkg-config --modversion quantlib)"
            else
                echo "✗ $desc: not found"
            fi
        else
            echo "✓ $desc: $(eval "${cmd} -version 2>&1 | head -n1" || ${cmd} --version 2>&1 | head -n1)"
        fi
    else
        echo "✗ $desc: not found"
    fi
}

verify_cmd "java" "Java"
verify_cmd "mvn" "Maven"
verify_cmd "swig" "SWIG"
verify_cmd "cmake" "CMake"
verify_cmd "pkg-config" "QuantLib"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Clone QuantLib-SWIG:"
echo "     git clone https://github.com/lballabio/QuantLib-SWIG.git"
echo ""
echo "  2. Run quick-build:"
echo "     cd quantlib4j-parent/scripts"
echo "     ./quick-build.sh /path/to/QuantLib-SWIG"
echo ""
