# QuantLib4J Docker Build Guide

## 概述

使用 Docker 构建 QuantLib4J，避免在本地安装复杂的 C++ 编译环境。

## 前置要求

- Docker 24+ 已安装并运行
- QuantLib-SWIG 已克隆

## 快速开始

### 1. 克隆 QuantLib-SWIG

```bash
cd /path/to/workspace
git clone https://github.com/lballabio/QuantLib-SWIG.git
```

### 2. Linux/macOS 构建

```bash
cd quantlib4j-parent

# 构建 Linux native library
./scripts/docker-build.sh linux

# 跳过 native build（仅生成 Java 代码）
./scripts/docker-build.sh linux --skip-native

# 构建所有平台
./scripts/docker-build.sh all

# 构建并发布到 Nexus
export NEXUS_USER=your_user
export NEXUS_PASS=your_pass
./scripts/docker-build.sh linux --deploy
```

### 3. Windows 构建

```batch
cd quantlib4j-parent\scripts

# 设置凭据（可选）
set NEXUS_USER=your_user
set NEXUS_PASS=your_pass

# 构建
docker-build.bat linux

# 指定 SWIG 目录
docker-build.bat linux --swig-dir D:\path\to\QuantLib-SWIG
```

## 脚本选项

| 选项 | 说明 |
|------|------|
| `linux` | 构建 Linux native library（默认）|
| `windows` | 构建 Windows native library |
| `macos` | 构建 macOS native library |
| `all` | 构建所有平台 |
| `--skip-swig` | 跳过 SWIG 代码生成 |
| `--skip-native` | 跳过 native library 编译 |
| `--deploy` | 构建后发布到 Nexus |
| `--swig-dir PATH` | 指定 QuantLib-SWIG 目录 |

## Docker 镜像

### Dockerfile.build

多平台编译环境镜像，包含：
- Ubuntu 22.04
- JDK 21
- SWIG 4.2+
- CMake, GCC
- QuantLib 1.34（从源码编译）

### quantlib4j-native-*/Dockerfile

平台特定镜像：
- `quantlib4j-native-linux/Dockerfile` - Ubuntu + libquantlib-dev
- `quantlib4j-native-windows/Dockerfile` - Windows Server Core + vcpkg
- `quantlib4j-native-macos/Dockerfile` - macOS cross-compile toolchain

## 发布到 Nexus

```bash
# 设置凭据
export NEXUS_USER=admin
export NEXUS_PASS=password

# 构建并发布
./scripts/docker-build.sh linux --deploy
```

发布后，在 `pom.xml` 中添加依赖：

```xml
<dependency>
    <groupId>com.luopc.platform.quantlib</groupId>
    <artifactId>quantlib4j</artifactId>
    <version>1.3.5-SNAPSHOT</version>
</dependency>
```

## 跨平台构建矩阵

| 目标平台 | Linux Host | Windows Host | macOS Host |
|----------|------------|--------------|------------|
| Linux | ✓ | ✗ | ✗ |
| Windows | ✗ | ✓ | ✗ |
| macOS | ✗ | ✗ | ✓ |

## 故障排除

### Docker not running

```bash
# Linux/macOS
sudo systemctl start docker

# Windows
Start-Process Docker Desktop
```

### QuantLib-SWIG not found

```bash
# 克隆到项目同级目录
cd /path/to/workspace
git clone https://github.com/lballabio/QuantLib-SWIG.git

# 或指定路径
./scripts/docker-build.sh linux --swig-dir /path/to/QuantLib-SWIG
```

### Native build fails

```bash
# 使用 --skip-native 跳过 native build
./scripts/docker-build.sh linux --skip-native

# 稍后在目标平台编译 native library
```
