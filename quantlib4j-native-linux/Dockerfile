# quantlib4j-native-linux/Dockerfile
# Build environment for Linux x64 native library

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    g++ \
    swig \
    openjdk-21-jdk \
    libquantlib-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

WORKDIR /build

# Default command builds the native library
CMD ["/bin/bash", "/build/build.sh"]
