@echo off
REM docker-build.bat - Build QuantLib4J using Docker (Windows)
REM Usage: docker-build.bat [PLATFORM] [OPTIONS]
REM
REM Platforms: linux, windows, macos, all (default: linux)
REM
REM Options:
REM   --skip-swig    Skip SWIG code generation
REM   --skip-native  Skip native library compilation
REM   --deploy       Deploy to Nexus after build
REM   --swig-dir     QuantLib-SWIG directory path
REM
REM Examples:
REM   docker-build.bat linux
REM   docker-build.bat all --deploy
REM   docker-build.bat linux --swig-dir D:\QuantLib-SWIG
REM
REM Requirements:
REM   - Docker Desktop installed and running
REM   - QuantLib-SWIG cloned
REM
REM Environment variables:
REM   NEXUS_USER        - Nexus username (required for --deploy)
REM   NEXUS_PASS        - Nexus password (required for --deploy)

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."
set "PROJECT_VERSION=1.3.5-SNAPSHOT"
set "QUANTLIB_VERSION=1.41"
set "JAVA_PACKAGE=com.luopc.platform.quantlib"

REM Default values
set "PLATFORM=linux"
set "SKIP_SWIG=false"
set "SKIP_NATIVE=false"
set "DEPLOY=false"
set "SWIG_DIR="

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="linux" set "PLATFORM=linux" & shift & goto :parse_args
if /i "%~1"=="windows" set "PLATFORM=windows" & shift & goto :parse_args
if /i "%~1"=="macos" set "PLATFORM=macos" & shift & goto :parse_args
if /i "%~1"=="all" set "PLATFORM=all" & shift & goto :parse_args
if /i "%~1"=="--skip-swig" set "SKIP_SWIG=true" & shift & goto :parse_args
if /i "%~1"=="--skip-native" set "SKIP_NATIVE=true" & shift & goto :parse_args
if /i "%~1"=="--deploy" set "DEPLOY=true" & shift & goto :parse_args
if /i "%~1"=="--swig-dir" set "SWIG_DIR=%~2" & shift & shift & goto :parse_args
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args

:args_done

REM Auto-detect SWIG_DIR if not specified
if "%SWIG_DIR%"=="" (
    if exist "%WORKSPACE%\..\..\QuantLib-SWIG\SWIG\quantlib.i" (
        set "SWIG_DIR=%WORKSPACE%\..\..\QuantLib-SWIG"
    ) else if exist "%WORKSPACE%\..\QuantLib-SWIG\SWIG\quantlib.i" (
        set "SWIG_DIR=%WORKSPACE%\..\QuantLib-SWIG"
    ) else (
        echo ERROR: QuantLib-SWIG not found
        echo Please specify with --swig-dir or clone to ..\..\QuantLib-SWIG
        exit /b 1
    )
)

if not exist "%SWIG_DIR%\SWIG\quantlib.i" (
    echo ERROR: quantlib.i not found in %SWIG_DIR%\SWIG\
    exit /b 1
)

echo ==============================================
echo   QuantLib4J Docker Build (Windows)
echo ==============================================
echo Platform:       %PLATFORM%
echo Project Version: %PROJECT_VERSION%
echo QuantLib Version: %QUANTLIB_VERSION%
echo SWIG Directory: %SWIG_DIR%
echo Workspace:      %WORKSPACE%
echo Skip SWIG:     %SKIP_SWIG%
echo Skip Native:    %SKIP_NATIVE%
echo Deploy:         %DEPLOY%
echo ==============================================

REM Check Docker
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

for /f "tokens=*" %%i in ('docker version --format "{{.Server.Version}}"') do set "DOCKER_VERSION=%%i"
echo Docker version: %DOCKER_VERSION%

REM Build Docker image
set "BUILD_IMAGE=quantlib4j-builder:latest"
echo.
echo [1/5] Building Docker build image...

docker build -f "%WORKSPACE%\Dockerfile.build" ^
    --build-arg QUANTLIB_VERSION=%QUANTLIB_VERSION% ^
    -t "%BUILD_IMAGE%" ^
    "%WORKSPACE%" 2>nul

if errorlevel 1 (
    echo Building without cache...
    docker build -f "%WORKSPACE%\Dockerfile.build" ^
        --build-arg QUANTLIB_VERSION=%QUANTLIB_VERSION% ^
        --no-cache ^
        -t "%BUILD_IMAGE%" ^
        "%WORKSPACE%"
)

echo   OK: Build image ready: %BUILD_IMAGE%

REM Step 2: Generate SWIG Java code
if "%SKIP_SWIG%"=="true" (
    echo.
    echo [2/5] Skipping SWIG generation ^(--skip-swig^)
) else (
    echo.
    echo [2/5] Generating SWIG Java code...

    docker run --rm ^
        -v "%SWIG_DIR%:C:\QuantLib-SWIG:ro" ^
        -v "%WORKSPACE%:C:\workspace" ^
        -w C:\workspace ^
        "%BUILD_IMAGE%" ^
        cmd /c "cd C:\QuantLib-SWIG\SWIG && swig -c++ -java -package %JAVA_PACKAGE% -outdir C:\workspace\quantlib4j-java\src\main\java -o quantlib_wrap.cpp quantlib.i"

    if errorlevel 1 (
        echo ERROR: SWIG generation failed
        exit /b 1
    )

    echo   OK: SWIG Java code generated
)

REM Step 3: Build Java module
echo.
echo [3/5] Building Java module...
cd /d "%WORKSPACE%"

call mvn clean install -pl quantlib4j-java -DskipTests -q

if errorlevel 1 (
    echo ERROR: Java module build failed
    exit /b 1
)
echo   OK: Java JAR built

REM Step 4: Build native libraries
if "%SKIP_NATIVE%"=="true" (
    echo.
    echo [4/5] Skipping native build ^(--skip-native^)
) else (
    echo.
    echo [4/5] Building native libraries...

    if "%PLATFORM%"=="linux" (
        echo.
        echo   Building Linux native library...

        docker build -f "%WORKSPACE%\quantlib4j-native-linux\Dockerfile" ^
            -t "quantlib4j-builder-linux:latest" ^
            "%WORKSPACE%" 2>nul || true

        docker run --rm ^
            -v "%SWIG_DIR%:C:\QuantLib-SWIG:ro" ^
            -v "%WORKSPACE%:C:\workspace" ^
            -w C:\workspace ^
            "quantlib4j-builder-linux:latest" ^
            bash -c "
                cd C:\QuantLib-SWIG\SWIG
                g++ -shared -fPIC \
                    -I\${JAVA_HOME}/include -I\${JAVA_HOME}/include/linux \
                    \$(pkg-config --cflags quantlib) \
                    quantlib_wrap.cpp \
                    \$(pkg-config --libs quantlib) \
                    -o libquantlib4j.so
                cp libquantlib4j.so /C/workspace/quantlib4j-native-linux/src/main/resources/
            "

        if exist "%WORKSPACE%\quantlib4j-native-linux\src\main\resources\libquantlib4j.so" (
            call mvn clean install -pl quantlib4j-native-linux -DskipTests -q
            echo   OK: Linux native JAR built
        )
    )

    if "%PLATFORM%"=="windows" (
        echo.
        echo   Building Windows native library...

        docker build -f "%WORKSPACE%\quantlib4j-native-windows\Dockerfile" ^
            -t "quantlib4j-builder-windows:latest" ^
            "%WORKSPACE%" 2>nul || true

        REM Note: Windows containers require Windows host, this may not work on Linux/macOS
        docker run --rm ^
            -v "%SWIG_DIR%:C:\QuantLib-SWIG:ro" ^
            -v "%WORKSPACE%:C:\workspace" ^
            -w C:\workspace ^
            "quantlib4j-builder-windows:latest" ^
            cmd /c "cd C:\QuantLib-SWIG\SWIG && cl /LD /EHsc /std:c++17 ..."

        if exist "%WORKSPACE%\quantlib4j-native-windows\src\main\resources\quantlib4j.dll" (
            call mvn clean install -pl quantlib4j-native-windows -DskipTests -q
            echo   OK: Windows native JAR built
        )
    )

    if "%PLATFORM%"=="macos" (
        echo.
        echo   WARNING: macOS build requires macOS Docker host ^(Docker Desktop on macOS^)
    )

    if "%PLATFORM%"=="all" (
        echo.
        echo   Building all platforms ^(use separate hosts for Windows/macOS^)...
        echo   Only Linux build available on current host
    )
)

REM Step 5: Build loader module
echo.
echo [5/5] Building loader module...
cd /d "%WORKSPACE%"

call mvn clean install -pl quantlib4j-loader -DskipTests -q

if errorlevel 1 (
    echo ERROR: Loader module build failed
    exit /b 1
)
echo   OK: Loader JAR built

REM Step 6: Deploy to Nexus
if "%DEPLOY%"=="true" (
    echo.
    echo [Deploy] Publishing to Nexus...

    if "%NEXUS_USER%"=="" (
        echo ERROR: NEXUS_USER must be set for --deploy
        exit /b 1
    )

    if "%NEXUS_PASS%"=="" (
        echo ERROR: NEXUS_PASS must be set for --deploy
        exit /b 1
    )

    set "SETTINGS_FILE=%WORKSPACE%\settings.xml"

    (
        echo ^<?xml version="1.0" encoding="UTF-8"?^>
        echo ^<settings^>
        echo   ^<servers^>
        echo     ^<server^>
        echo       ^<id^>deploy-release^</id^>
        echo       ^<username^>%NEXUS_USER%^</username^>
        echo       ^<password^>%NEXUS_PASS%^</password^>
        echo     ^</server^>
        echo     ^<server^>
        echo       ^<id^>deploy-snapshot^</id^>
        echo       ^<username^>%NEXUS_USER%^</username^>
        echo       ^<password^>%NEXUS_PASS%^</password^>
        echo     ^</server^>
        echo   ^</servers^>
        echo ^</settings^>
    ) > "%SETTINGS_FILE%"

    cd /d "%WORKSPACE%\quantlib4j-parent"
    call mvn deploy -DskipTests -s "%SETTINGS_FILE%" -P release

    del /q "%SETTINGS_FILE%" 2>nul

    if errorlevel 1 (
        echo ERROR: Deploy failed
        exit /b 1
    )

    echo.
    echo   OK: Deployed to Nexus
)

echo.
echo ==============================================
echo   Build Complete!
echo ==============================================
echo.
echo Artifacts:
if exist "%WORKSPACE%\quantlib4j-java\target\*.jar" dir /b "%WORKSPACE%\quantlib4j-java\target\*.jar"
if exist "%WORKSPACE%\quantlib4j-native-linux\target\*.jar" dir /b "%WORKSPACE%\quantlib4j-native-linux\target\*.jar"
echo.
echo Next steps:
echo   1. Add dependency to valuation-service pom.xml
echo   2. Build: cd pricing-service-parent ^&^& mvn clean install -pl valuation-service -am

endlocal
exit /b 0

:show_help
echo Usage: docker-build.bat [PLATFORM] [OPTIONS]
echo.
echo Platforms:
echo   linux   - Build Linux native library ^(default^)
echo   windows - Build Windows native library
echo   macos   - Build macOS native library
echo   all     - Build all platforms
echo.
echo Options:
echo   --skip-swig    Skip SWIG code generation
echo   --skip-native  Skip native library compilation
echo   --deploy       Deploy to Nexus after build
echo   --swig-dir     QuantLib-SWIG directory
echo   --help         Show this help
echo.
echo Environment variables:
echo   NEXUS_USER     Nexus username ^(required for --deploy^)
echo   NEXUS_PASS     Nexus password ^(required for --deploy^)
exit /b 0
