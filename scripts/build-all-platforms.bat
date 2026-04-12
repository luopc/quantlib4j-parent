@echo off
REM build-all-platforms.bat - Build QuantLib4J for all platforms (Windows)
REM Usage: build-all-platforms.bat [OPTIONS]
REM
REM Options:
REM   --skip-native    Skip native library compilation
REM   --deploy         Deploy to Nexus after build
REM   --swig-dir       QuantLib-SWIG directory path
REM
REM Requirements:
REM   - Docker Desktop installed and running
REM   - QuantLib-SWIG cloned at ..\..\QuantLib-SWIG (or specify path)

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."
set "PROJECT_VERSION=1.3.5-SNAPSHOT"

REM Default values
set "SKIP_NATIVE=false"
set "DEPLOY=false"
set "SWIG_DIR="

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
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
    )
)

echo ==============================================
echo   QuantLib4J Multi-Platform Build
echo ==============================================
echo Workspace:    %WORKSPACE%
echo SWIG Dir:     %SWIG_DIR%
echo Skip Native:  %SKIP_NATIVE%
echo Deploy:       %DEPLOY%
echo ==============================================

REM Check Docker
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

echo.
echo [1/4] Building Java module...
cd /d "%WORKSPACE%"
call mvn clean install -pl quantlib4j-java -DskipTests -q
echo   OK: Java JAR built

if "%SKIP_NATIVE%"=="true" (
    echo.
    echo [Skip] Skipping native builds ^(--skip-native^)
) else (
    echo.
    echo [2/4] Building Linux native library...
    echo   INFO: Use docker-build.sh on Linux/macOS for full Linux build

    if exist "%WORKSPACE%\quantlib4j-native-linux\src\main\resources\libquantlib4j.so" (
        call mvn clean install -pl quantlib4j-native-linux -DskipTests -q
        echo   OK: Linux native JAR built ^(pre-built^)
    ) else (
        echo   SKIP: Native library not found
    )

    echo.
    echo [3/4] Building Windows native library...

    if exist "%WORKSPACE%\quantlib4j-native-windows\Dockerfile" (
        docker build -f "%WORKSPACE%\quantlib4j-native-windows\Dockerfile" ^
            -t "quantlib4j-builder-windows:latest" ^
            "%WORKSPACE%" 2>nul || true

        docker run --rm ^
            -v "%WORKSPACE%:C:\workspace" ^
            -w C:\workspace ^
            "quantlib4j-builder-windows:latest" ^
            cmd /c "cd C:\workspace\QuantLib-SWIG\SWIG && cl /LD /EHsc /std:c++17 ..."
    ) else (
        echo   SKIP: Dockerfile not found
    )

    if exist "%WORKSPACE%\quantlib4j-native-windows\src\main\resources\quantlib4j.dll" (
        call mvn clean install -pl quantlib4j-native-windows -DskipTests -q
        echo   OK: Windows native JAR built
    )

    echo.
    echo [4/4] Building macOS native library...
    echo   INFO: Use docker-build.sh on macOS for macOS native build
)

REM Build loader module
echo.
echo [Final] Building loader module...
call mvn clean install -pl quantlib4j-loader -DskipTests -q
echo   OK: Loader JAR built

REM Deploy to Nexus
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

    cd /d "%WORKSPACE%"
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
if exist "%WORKSPACE%\quantlib4j-native-windows\target\*.jar" dir /b "%WORKSPACE%\quantlib4j-native-windows\target\*.jar"
echo.
echo Platform JARs:
echo   - quantlib4j-java:      Java bindings
echo   - quantlib4j-loader:    Native library loader
echo   - quantlib4j-native-linux:   Linux native library
echo   - quantlib4j-native-windows: Windows native library

endlocal
exit /b 0

:show_help
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   --skip-native    Skip native library compilation
echo   --deploy         Deploy to Nexus after build
echo   --swig-dir DIR   QuantLib-SWIG directory
echo   --help           Show this help
echo.
echo Environment variables:
echo   NEXUS_USER        Nexus username
echo   NEXUS_PASS        Nexus password
exit /b 0
