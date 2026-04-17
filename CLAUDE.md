# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Full build (from quantlib4j-parent)
mvn clean install

# Build single module
mvn clean install -pl quantlib4j-java -am
mvn clean install -pl quantlib4j-native-linux -am

# Build native library only (requires Linux with QuantLib installed)
cd scripts
./build-native.sh

# Quick build (requires dependencies pre-installed)
./quick-build.sh /path/to/QuantLib-SWIG

# Check environment
./check-env.sh
```

## Project Structure

```
quantlib4j-parent/
├── pom.xml                          # Parent POM (version: 1.42.0-SNAPSHOT)
├── scripts/                         # Build scripts
│   ├── build-native.sh             # Linux native library build
│   ├── quick-build.sh/.bat         # Quick build (SWIG + Java + native)
│   ├── check-env.sh/.bat           # Environment check
│   └── docker-build.sh/.bat        # Docker cross-platform build
├── quantlib4j-java/                 # Java bindings module
├── quantlib4j-loader/               # Native library loader
├── quantlib4j-native-linux/        # Linux native library (x64)
├── quantlib4j-native-windows/      # Windows native library (x64)
├── quantlib4j-native-macos/        # macOS native library (x64)
└── quantlib4j-integration-test/    # Integration tests
```

## Tech Stack

| Component | Version |
|-----------|---------|
| Java | 21 |
| Maven | 3.9+ |
| QuantLib | 1.42 |
| SWIG | 4.4+ |

## Dependencies

### Required
- **SWIG 4.4+**: For generating Java bindings from C++
- **QuantLib 1.42**: Quantitative finance library

### Linux (Ubuntu 24.04 / AlmaLinux 9)
```bash
# Ubuntu
sudo apt-get install build-essential cmake swig libboost-all-dev libquantlib-dev

# AlmaLinux 9
sudo dnf install gcc-c++ cmake swig boost-devel quantlib-devel
```

### macOS
```bash
brew install quantlib swig cmake
```

### Windows
- Visual Studio 2022 Build Tools
- vcpkg: `vcpkg install quantlib:x64-windows-static`

## Native Build Profiles

| Profile | Classifier | Description |
|---------|------------|-------------|
| ubuntu24 | ubuntu24-x64 | Ubuntu 24.04 LTS |
| alma9 | alma9-x64 | AlmaLinux 9.7 |
| default | linux-x64 | Generic Linux |

Build with specific profile:
```bash
mvn clean install -pl quantlib4j-native-linux -P ubuntu24 -DskipTests
```

## Maven Artifacts

| Artifact | Description |
|----------|-------------|
| `com.luopc.platform.quantlib:quantlib4j-java` | Java bindings |
| `com.luopc.platform.quantlib:quantlib4j-linux-x64:ubuntu24-x64` | Linux native (Ubuntu 24) |
| `com.luopc.platform.quantlib:quantlib4j-linux-x64:alma9-x64` | Linux native (AlmaLinux 9) |
| `com.luopc.platform.quantlib:quantlib4j-windows-x64` | Windows native |
| `com.luopc.platform.quantlib:quantlib4j-macos-x64` | macOS native |

## Usage in Other Projects

Add dependency to pom.xml:
```xml
<dependency>
    <groupId>com.luopc.platform.quantlib</groupId>
    <artifactId>quantlib4j</artifactId>
    <version>1.42.0-SNAPSHOT</version>
</dependency>
```

## Scripts

| Script | Purpose |
|--------|---------|
| `build-native.sh` | Build native library on Linux (5 steps) |
| `quick-build.sh` | Fast build (requires deps installed) |
| `check-env.sh` | Verify build environment |
| `docker-build.sh` | Cross-platform Docker build |

## Important Paths

- Java source: `quantlib4j-java/src/main/java/com/luopc/platform/quantlib/`
- Native resources: `quantlib4j-native-*/src/main/resources/`
- SWIG interface: `../QuantLib-SWIG/SWIG/quantlib.i` (expected sibling directory)
