# quantlib4j-native-windows/Dockerfile
# Build environment for Windows x64 native library

FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install Chocolatey
RUN powershell -Command \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = \
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install build tools
RUN choco install -y \
    swig \
    visualstudio2022buildtools \
    jdk21

# Set Java environment
ENV JAVA_HOME="C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.2.13-hotspot"
ENV PATH="$JAVA_HOME\\bin;$PATH"

WORKDIR C:\\build

CMD ["powershell", "C:\\build\\build.ps1"]
