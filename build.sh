#!/bin/bash

set -eo pipefail

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}"

# Print help information
usage() {
  echo -e "${CYAN}Usage: $0 [OPTIONS] [release|snapshot]${NC}"
  echo ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${GREEN}-p, --platform <platform>${NC}  Build specific platform"
  echo -e "                               ${YELLOW}ubuntu24${NC}  - Ubuntu 24.04 x64"
  echo -e "                               ${YELLOW}alma9${NC}      - AlmaLinux 9 x64"
  echo -e "                               ${YELLOW}windows${NC}    - Windows x64"
  echo -e "                               ${YELLOW}linux${NC}      - All Linux platforms"
  echo -e "                               ${YELLOW}all${NC}        - All platforms (default)"
  echo -e "  ${GREEN}-m, --module <module>${NC}      Build specific Maven module"
  echo -e "                               ${YELLOW}java${NC}       - quantlib4j-java only"
  echo -e "                               ${YELLOW}loader${NC}     - quantlib4j-loader only"
  echo -e "                               ${YELLOW}linux-native${NC}  - Linux native library"
  echo -e "                               ${YELLOW}windows-native${NC}- Windows native library"
  echo -e "  ${GREEN}--skip-tests${NC}                Skip tests"
  echo -e "  ${GREEN}--skip-native${NC}              Skip native library compilation"
  echo -e "  ${GREEN}-h, --help${NC}                 Show this help message"
  echo ""
  echo -e "${CYAN}Arguments:${NC}"
  echo -e "  ${GREEN}release${NC}   - Build and release a new version"
  echo -e "  ${GREEN}snapshot${NC}  - Build and deploy a snapshot version (default)"
  echo ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  ${YELLOW}$0 snapshot${NC}                     # Deploy all modules as snapshot"
  echo -e "  ${YELLOW}$0 -p ubuntu24 snapshot${NC}           # Deploy Ubuntu 24 native only"
  echo -e "  ${YELLOW}$0 -p alma9 snapshot${NC}             # Deploy AlmaLinux 9 native only"
  echo -e "  ${YELLOW}$0 -p windows snapshot${NC}            # Deploy Windows native only"
  echo -e "  ${YELLOW}$0 -p linux -m java snapshot${NC}     # Deploy all Linux natives + Java bindings"
  echo -e "  ${YELLOW}$0 release${NC}                       # Release all modules"
  exit 1
}

# Default values
BUILD_TYPE="snapshot"
PLATFORM="all"
MODULE=""
SKIP_TESTS=""
SKIP_NATIVE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    -m|--module)
      MODULE="$2"
      shift 2
      ;;
    --skip-tests)
      SKIP_TESTS="-DskipTests"
      shift
      ;;
    --skip-native)
      SKIP_NATIVE="true"
      shift
      ;;
    -h|--help)
      usage
      ;;
    release|snapshot)
      BUILD_TYPE="$1"
      shift
      ;;
    *)
      echo -e "${RED}Error: Unknown argument: $1${NC}"
      usage
      ;;
  esac
done

# Validate platform
case "$PLATFORM" in
  ubuntu24|alma9|windows|linux|all)
    ;;
  *)
    echo -e "${RED}Error: Invalid platform: $PLATFORM${NC}"
    echo -e "${YELLOW}Valid platforms: ubuntu24, alma9, windows, linux, all${NC}"
    exit 1
    ;;
esac

# Build Maven modules based on platform and module selection
build_modules() {
  local modules=""

  # Add base modules
  if [ -z "$MODULE" ] || [ "$MODULE" == "java" ]; then
    modules="${modules}quantlib4j-java"
  fi

  if [ -z "$MODULE" ] || [ "$MODULE" == "loader" ]; then
    modules="${modules} quantlib4j-loader"
  fi

  # Linux native modules
  if [ "$PLATFORM" == "linux" ] || [ "$PLATFORM" == "all" ]; then
    if [ -z "$SKIP_NATIVE" ]; then
      modules="${modules} quantlib4j-native-linux"
    fi
  elif [ "$PLATFORM" == "ubuntu24" ]; then
    if [ -z "$SKIP_NATIVE" ]; then
      modules="${modules} quantlib4j-native-linux"
    fi
  elif [ "$PLATFORM" == "alma9" ]; then
    if [ -z "$SKIP_NATIVE" ]; then
      modules="${modules} quantlib4j-native-linux"
    fi
  fi

  # Windows native module
  if [ "$PLATFORM" == "windows" ] || [ "$PLATFORM" == "all" ]; then
    if [ -z "$SKIP_NATIVE" ]; then
      modules="${modules} quantlib4j-native-windows"
    fi
  fi

  # Add integration test
  if [ -z "$MODULE" ]; then
    modules="${modules} quantlib4j-integration-test"
  fi

  echo "$modules"
}

start_time=$(date +%s)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  QuantLib4J Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Build Type:   ${GREEN}$BUILD_TYPE${NC}"
echo -e "${CYAN}Platform:     ${GREEN}$PLATFORM${NC}"
if [ -n "$MODULE" ]; then
  echo -e "${CYAN}Module:       ${GREEN}$MODULE${NC}"
fi
if [ -n "$SKIP_TESTS" ]; then
  echo -e "${CYAN}Skip Tests:   ${GREEN}yes${NC}"
fi
echo -e "${BLUE}========================================${NC}"

# Check if we need to build native libraries
need_native=false
if [ "$PLATFORM" != "all" ] && [ "$PLATFORM" != "linux" ] && [ "$PLATFORM" != "windows" ] && [ "$PLATFORM" != "ubuntu24" ] && [ "$PLATFORM" != "alma9" ]; then
  if [ -z "$SKIP_NATIVE" ]; then
    need_native=true
  fi
fi

# Build with specific profiles for native libraries
build_cmd="mvn -B clean deploy"

# Add platform-specific profiles
if [ "$PLATFORM" == "ubuntu24" ]; then
  build_cmd="$build_cmd -P ubuntu24"
  echo -e "${YELLOW}Building Ubuntu 24.04 native library${NC}"
elif [ "$PLATFORM" == "alma9" ]; then
  build_cmd="$build_cmd -P alma9"
  echo -e "${YELLOW}Building AlmaLinux 9 native library${NC}"
elif [ "$PLATFORM" == "windows" ]; then
  echo -e "${YELLOW}Building Windows native library${NC}"
elif [ "$PLATFORM" == "linux" ]; then
  echo -e "${YELLOW}Building all Linux native libraries${NC}"
elif [ "$PLATFORM" == "all" ]; then
  echo -e "${YELLOW}Building all native libraries${NC}"
fi

# Add test skip if specified
if [ -n "$SKIP_TESTS" ]; then
  build_cmd="$build_cmd $SKIP_TESTS"
fi

# Add skip native if specified
if [ -n "$SKIP_NATIVE" ]; then
  build_cmd="$build_cmd -DskipNative=true"
fi

# Execute build
if [ "$BUILD_TYPE" = "release" ]; then
  echo -e "${GREEN}Building Release Version${NC}"

  # Clean workspace
  if ! git clean -fdx; then
    echo -e "${RED}Error: Failed to clean workspace${NC}"
    exit 1
  fi

  # Update dependency versions
  mvn versions:use-latest-releases -Dincludes=com.luopc.platform.parent* -DgenerateBackupPoms=false -DallowSnapshots=false

  # Detect version changes
  echo -e "${YELLOW}Detecting version changes${NC}"
  changes=$(git status --porcelain)
  if [ -n "$changes" ]; then
    echo -e "${GREEN}Changes detected, committing version updates${NC}"
    git add .

    if ! git diff --cached --quiet; then
      if ! git commit -m "chore: auto commit version updates"; then
        echo -e "${RED}Error: Failed to commit version changes${NC}"
        exit 1
      fi
      echo -e "${GREEN}Version changed and committed${NC}"
    fi
  fi

  VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:3.5.1:exec | awk -v FS="-" '{print $1}')

  # Execute release
  echo -e "${GREEN}Starting release build${NC}"
  if ! $build_cmd -P uat release:prepare release:perform -Dmaven.javadoc.skip=true; then
    echo -e "${RED}Error: Release build failed${NC}"
    exit 1
  fi

  end_time=$(date +%s)
  echo -e "${YELLOW}[INFO] Released version: $VERSION, duration: $((end_time - start_time))s${NC}"

elif [ "$BUILD_TYPE" = "snapshot" ]; then
  echo -e "${GREEN}Building Snapshot Version${NC}"

  if ! $build_cmd -P uat; then
    echo -e "${RED}Error: Snapshot build failed${NC}"
    exit 1
  fi

  # Get version number
  VERSION=$(mvn -q -Dexec.executable="echo" \
    -Dexec.args='${project.version}' \
    --non-recursive \
    org.codehaus.mojo:exec-maven-plugin:1.6.0:exec)

  end_time=$(date +%s)
  echo -e "${YELLOW}[INFO] Deployed snapshot version: ${VERSION}, duration: $((end_time - start_time))s${NC}"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
