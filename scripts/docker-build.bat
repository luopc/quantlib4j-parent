@echo off
REM docker-build.bat - Build QuantLib4J using Docker (Windows)

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."
set "PROJECT_VERSION=1.3.5-SNAPSHOT"
set "QUANTLIB_VERSION=1.41"
set "JAVA_PACKAGE=com.luopc.platform.quantlib"

REM Ensure absolute paths
for %%i in ("%WORKSPACE%") do set "WORKSPACE=%%~fi"

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

REM Auto-detect SWIG_DIR
if "%SWIG_DIR%"=="" (
    if exist "%WORKSPACE%\..\..\QuantLib-SWIG\SWIG\quantlib.i" (
        set "SWIG_DIR=%WORKSPACE%\..\..\QuantLib-SWIG"
    ) else if exist "%WORKSPACE%\..\QuantLib-SWIG\SWIG\quantlib.i" (
        set "SWIG_DIR=%WORKSPACE%\..\QuantLib-SWIG"
    ) else (
        echo ERROR: QuantLib-SWIG not found
        exit /b 1
    )
)

for %%i in ("%SWIG_DIR%") do set "SWIG_DIR=%%~fi"

echo ==============================================
echo   QuantLib4J Docker Build
echo ==============================================
echo Workspace: %WORKSPACE%
echo Platform: %PLATFORM%
echo ==============================================

REM Check Docker
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running
    exit /b 1
)

REM Build Docker image
set "BUILD_IMAGE=quantlib4j-builder:latest"
echo.
echo [1/3] Building Docker build image...
docker build -f "%WORKSPACE%\Dockerfile.build" --build-arg QUANTLIB_VERSION=%QUANTLIB_VERSION% -t "%BUILD_IMAGE%" "%WORKSPACE%" 2>nul
if errorlevel 1 (
    echo Building without cache...
    docker build -f "%WORKSPACE%\Dockerfile.build" --build-arg QUANTLIB_VERSION=%QUANTLIB_VERSION% --no-cache -t "%BUILD_IMAGE%" "%WORKSPACE%"
)
echo OK: Build image ready

REM Generate SWIG code
if not "%SKIP_SWIG%"=="true" goto :skip_swig
echo.
echo [2/3] Generating SWIG Java code...
docker run --rm -v "!SWIG_DIR!:/QuantLib-SWIG:ro" -v "!WORKSPACE!:/workspace:rw" -w /workspace "%BUILD_IMAGE%" bash -c "rm -rf /workspace/quantlib4j-java/src/main/java/com/luopc/platform/quantlib && mkdir -p /workspace/quantlib4j-java/src/main/java/com/luopc/platform/quantlib && cd /QuantLib-SWIG/SWIG && swig -c++ -java -package %JAVA_PACKAGE% -outdir /workspace/quantlib4j-java/src/main/java/com/luopc/platform/quantlib -o /workspace/quantlib_wrap.cpp quantlib.i"
if errorlevel 1 (
    echo ERROR: SWIG generation failed
    exit /b 1
)
echo OK: SWIG code generated
:skip_swig

REM Build Java modules
echo.
echo [3/3] Building Java modules...
cd /d "%WORKSPACE%"
call mvn clean install -pl quantlib4j-java -DskipTests
if errorlevel 1 (
    echo ERROR: Java module build failed
    exit /b 1
)

call mvn clean install -pl quantlib4j-loader -DskipTests
if errorlevel 1 (
    echo ERROR: Loader module build failed
    exit /b 1
)

echo OK: All modules built
echo.
echo ==============================================
echo   Build Complete!
echo ==============================================

endlocal
exit /b 0

:show_help
echo Usage: docker-build.bat [PLATFORM] [OPTIONS]
echo.
echo Platforms: linux, windows, macos, all
echo Options: --skip-swig, --skip-native, --deploy, --swig-dir DIR
exit /b 0
