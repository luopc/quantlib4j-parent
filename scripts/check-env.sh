#!/bin/bash
#
# check-env.sh - Check QuantLib4J build environment (Linux/macOS)
#
# Usage:
#   ./check-env.sh              # Check all dependencies
#   ./check-env.sh --json       # Output in JSON format
#   ./check-env.sh --verbose    # Show detailed information
#
# Author: Claude
# Date: 2026-04-11

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Options
JSON_OUTPUT=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json       Output in JSON format"
            echo "  --verbose    Show detailed information"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# JSON output helper
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Check command exists
check_command() {
    local cmd="$1"
    local desc="${2:-}"
    local required="${3:-false}"

    local result
    local version=""
    local status="ok"

    if command -v "$cmd" &> /dev/null; then
        version=$(eval "${cmd} -version 2>&1 | head -n1" || ${cmd} --version 2>&1 | head -n1 || echo "found")
        result="✓ FOUND"
    else
        if [[ "$required" == "true" ]]; then
            status="error"
            result="✗ MISSING"
        else
            status="warning"
            result="⚠ MISSING"
        fi
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"name\":\"$cmd\",\"status\":\"$status\",\"version\":\"$(json_escape "$version")\",\"description\":\"$(json_escape "$desc")\"}"
    else
        printf "  %-8s %-12s %s\n" "$result" "[$cmd]" "$desc"
        if [[ "$VERBOSE" == "true" && -n "$version" ]]; then
            echo "           → $version"
        fi
    fi
}

# Check package (pkg-config)
check_package() {
    local pkg="$1"
    local desc="${2:-}"
    local required="${3:-false}"

    local result
    local version=""
    local status

    if pkg-config --exists "$pkg" 2>/dev/null; then
        version=$(pkg-config --modversion "$pkg" 2>/dev/null || echo "found")
        result="✓ FOUND"
        status="ok"
    else
        if [[ "$required" == "true" ]]; then
            status="error"
            result="✗ MISSING"
        else
            status="warning"
            result="⚠ MISSING"
        fi
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"name\":\"$pkg\",\"status\":\"$status\",\"version\":\"$(json_escape "$version")\",\"description\":\"$(json_escape "$desc")\"}"
    else
        printf "  %-8s %-12s %s\n" "$result" "[$pkg]" "$desc"
        if [[ "$VERBOSE" == "true" && -n "$version" ]]; then
            echo "           → $version"
        fi
    fi
}

# Check directory exists
check_directory() {
    local dir="$1"
    local desc="${2:-}"
    local required="${3:-false}"

    local result
    local status

    if [[ -d "$dir" ]]; then
        result="✓ FOUND"
        status="ok"
    else
        if [[ "$required" == "true" ]]; then
            status="error"
            result="✗ MISSING"
        else
            status="warning"
            result="⚠ MISSING"
        fi
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"name\":\"$dir\",\"status\":\"$status\",\"type\":\"directory\",\"description\":\"$(json_escape "$desc")\"}"
    else
        printf "  %-8s %-12s %s\n" "$result" "[DIR]" "$desc"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "           → $dir"
        fi
    fi
}

# Get OS info
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$PRETTY_NAME"
    elif [[ "$(uname)" == "Darwin" ]]; then
        sw_vers | tr '\n' ' '
    else
        uname -a
    fi
}

# Get architecture
get_arch() {
    uname -m
}

# Get kernel
get_kernel() {
    uname -r
}

# Main
main() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{"
        echo "  \"environment\": {"
        echo "    \"os\": \"$(json_escape "$(get_os_info)")\","
        echo "    \"arch\": \"$(get_arch)\","
        echo "    \"kernel\": \"$(json_escape "$(get_kernel)")\","
        echo "    \"timestamp\": \"$(date -Iseconds)\""
        echo "  },"
        echo "  \"checks\": ["
    else
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         QuantLib4J Build Environment Check               ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}System:${NC}      $(get_os_info)"
        echo -e "${BLUE}Arch:${NC}        $(get_arch)"
        echo -e "${BLUE}Kernel:${NC}      $(get_kernel)"
        echo -e "${BLUE}User:${NC}        ${USER:-$(whoami)}"
        echo -e "${BLUE}Date:${NC}        $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${BLUE}[ Required Components ]${NC}"
    fi

    # Required checks
    local required_checks=()
    local optional_checks=()

    # Java
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        [[ $# -eq 0 ]] && echo "    " || echo ","
        check_command "java" "Java JDK 21+" true
    else
        check_command "java" "Java JDK 21+" true
    fi

    # Maven
    check_command "mvn" "Maven 3.9+" true

    # SWIG
    check_command "swig" "SWIG 4.2+" true

    # CMake
    check_command "cmake" "CMake 3.20+" false

    # GCC
    check_command "g++" "GCC/G++ 11+" false

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${BLUE}[ QuantLib Components ]${NC}"
    fi

    # QuantLib
    check_package "quantlib" "QuantLib 1.42+" true

    # QuantLib thread-safe flag
    if pkg-config --exists quantlib 2>/dev/null; then
        local ql_cflags=$(pkg-config --cflags quantlib 2>/dev/null || echo "")
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            [[ $# -eq 0 ]] && echo ","
            if echo "$ql_cflags" | grep -q "QL_ENABLE_THREAD_SAFE"; then
                echo "{\"name\":\"thread-safe\",\"status\":\"ok\",\"version\":\"enabled\",\"description\":\"Thread-safe observer pattern\"}"
            else
                echo "{\"name\":\"thread-safe\",\"status\":\"warning\",\"version\":\"disabled\",\"description\":\"Thread-safe observer pattern\"}"
            fi
        else
            printf "  %-8s %-12s %s\n" "[QL-CFG]" "thread-safe" ""
            if echo "$ql_cflags" | grep -q "QL_ENABLE_THREAD_SAFE"; then
                echo -e "           → ${GREEN}✓ Enabled${NC}"
            else
                echo -e "           → ${YELLOW}⚠ Disabled (recommended for JVM)${NC}"
            fi
        fi
    fi

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${BLUE}[ Directory Check ]${NC}"
    fi

    # Check workspace
    local workspace_dir="${WORKSPACE:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
    check_directory "$workspace_dir" "Workspace directory" false

    # Check QuantLib-SWIG
    local swig_dir="${workspace_dir}/../../../QuantLib-SWIG"
    swig_dir=$(readlink -f "$swig_dir" 2>/dev/null || echo "$swig_dir")
    if [[ -d "$swig_dir" ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo ","
            check_directory "$swig_dir" "QuantLib-SWIG source" false
        else
            check_directory "$swig_dir" "QuantLib-SWIG source" false
        fi
    fi

    # Check Java/JAVA_HOME
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo ","
        echo "{\"name\":\"JAVA_HOME\",\"status\":\"ok\",\"version\":\"$(json_escape "${JAVA_HOME:-not set}")\",\"description\":\"Java home directory\"}"
    else
        echo ""
        echo -e "${BLUE}[ Environment Variables ]${NC}"
        echo -e "  JAVA_HOME: ${YELLOW}${JAVA_HOME:-not set}${NC}"
        echo -e "  MAVEN_OPTS: ${MAVEN_OPTS:-not set}"
    fi

    # Summary
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo ""
        echo "  ],"
        echo "  \"summary\": {"
        echo "    \"required_ok\": true,"
        echo "    \"optional_ok\": true"
        echo "  }"
        echo "}"
    else
        # Detect package manager
        local pkg_manager=""
        local install_cmd=""
        if command -v dnf &> /dev/null; then
            pkg_manager="dnf"
            install_cmd="sudo dnf install -y"
        elif command -v apt-get &> /dev/null; then
            pkg_manager="apt-get"
            install_cmd="sudo apt-get update && sudo apt-get install -y"
        fi

        # Detect if QuantLib-SWIG exists
        local swig_source_status=""
        if [[ -d "$swig_dir" ]]; then
            swig_source_status="${GREEN}✓ Found${NC}"
        else
            swig_source_status="${YELLOW}⚠ Not found${NC}"
        fi

        echo ""
        echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${GREEN}✓${NC} Required tools: Java, Maven, SWIG"
        echo -e "${YELLOW}⚠${NC} Optional: CMake, GCC (for native builds)"
        echo ""
        echo -e "${GREEN}✓${NC} QuantLib: Required for native library compilation"
        echo ""
        echo "Status:"
        echo -e "  QuantLib-SWIG: $swig_source_status ($swig_dir)"
        echo ""
        echo "Next steps:"

        if [[ -n "$pkg_manager" ]]; then
            echo "  1. Install build tools:"
            if [[ "$pkg_manager" == "dnf" ]]; then
                echo "     $install_cmd gcc-c++ cmake swig boost-devel libicu-devel pcre2-devel"
                echo "     # QuantLib (if not in repos, use build-native.sh to build from source)"
            else
                echo "     $install_cmd build-essential cmake swig libboost-all-dev libicu-dev libpcre2-dev"
                echo "     # QuantLib: $install_cmd libquantlib-dev"
            fi
        fi

        echo "  2. Clone QuantLib-SWIG:"
        if [[ ! -d "$swig_dir" ]]; then
            echo "     git clone https://github.com/lballabio/QuantLib-SWIG.git ../QuantLib-SWIG"
        else
            echo "     ✓ Already exists"
        fi
        echo ""
        echo "  3. Build native library:"
        echo "     ./scripts/build-native.sh"
        echo ""
    fi
}

main "$@"
