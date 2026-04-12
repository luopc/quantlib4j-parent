# quantlib4j-native-macos/Dockerfile
# Build environment for macOS x64 native library

FROM ghcr.io/mmaciejewski/macos-cross-toolchains:latest

# Install dependencies via Homebrew
RUN brew install \
    swig \
    openjdk@21 \
    quantlib

# Set Java environment
ENV JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
ENV PATH=$JAVA_HOME/bin:$PATH

WORKDIR /build

CMD ["/bin/bash", "/build/build.sh"]
