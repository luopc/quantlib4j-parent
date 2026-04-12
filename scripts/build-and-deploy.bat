@echo off
REM build-and-deploy.bat - Build QuantLib4J and deploy to Nexus (Windows)
REM Usage: build-and-deploy.bat [SWIG_DIR]
REM
REM Environment variables:
REM   NEXUS_USER - Nexus username
REM   NEXUS_PASS - Nexus password
REM   QUANTLIB_VERSION - QuantLib version (default: 1.34)
REM
REM Example:
REM   set NEXUS_USER=admin
REM   set NEXUS_PASS=admin123
REM   build-and-deploy.bat D:\path\to\QuantLib-SWIG

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."
set "QUANTLIB_VERSION=1.34"
set "PROJECT_VERSION=1.3.5-SNAPSHOT"
set "JAVA_PACKAGE=com.luopc.platform.quantlib"

REM Default paths
if "%~1"=="" (
    set "SWIG_DIR=%WORKSPACE%\..\..\QuantLib-SWIG"
) else (
    set "SWIG_DIR=%~1"
)

echo ==============================================
echo   QuantLib4J Build & Deploy Script (Windows)
echo ==============================================
echo Project Version:  %PROJECT_VERSION%
echo QuantLib Version: %QUANTLIB_VERSION%
echo Java Package:     %JAVA_PACKAGE%
echo SWIG Directory:   %SWIG_DIR%
echo Workspace:       %WORKSPACE%
echo ==============================================

REM Check prerequisites
echo.
echo [1/6] Checking prerequisites...

where java >nul 2>&1
if errorlevel 1 (
    echo ERROR: Java not found. Please install JDK 21+
    exit /b 1
)
echo   OK: Java found

where mvn >nul 2>&1
if errorlevel 1 (
    echo ERROR: Maven not found. Please install Maven 3.9+
    exit /b 1
)
echo   OK: Maven found

where swig >nul 2>&1
if errorlevel 1 (
    echo ERROR: SWIG not found. Please install SWIG 4.2+
    exit /b 1
)
echo   OK: SWIG found

REM Check QuantLib-SWIG
if not exist "%SWIG_DIR%\SWIG\quantlib.i" (
    echo ERROR: QuantLib-SWIG not found at: %SWIG_DIR%
    echo Please specify the path: build-and-deploy.bat D:\path\to\QuantLib-SWIG
    exit /b 1
)
echo   OK: QuantLib-SWIG found

REM Check Java Home
if "%JAVA_HOME%"=="" (
    where java >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where java') do set "JAVA_BIN=%%i"
        for /f "delims=" %%i in ('powershell -Command "(Get-Item '%JAVA_BIN%').Directory.Parent.FullName"') do set "JAVA_HOME=%%i"
    )
)
echo   JAVA_HOME: %JAVA_HOME%

REM Check Nexus credentials
if "%NEXUS_USER%"=="" (
    echo.
    echo WARNING: NEXUS_USER or NEXUS_PASS not set.
    echo Build will proceed but deploy will be skipped.
    echo Set credentials with:
    echo   set NEXUS_USER=your_username
    echo   set NEXUS_PASS=your_password
    set "DO_DEPLOY=false"
) else (
    set "DO_DEPLOY=true"
)

REM Create Maven settings if deploying
set "MAVEN_SETTINGS=%WORKSPACE%\settings.xml"
if "%DO_DEPLOY%"=="true" (
    echo.
    echo [2/6] Configuring Maven settings...

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
    ) > "%MAVEN_SETTINGS%"

    echo   OK: Maven settings created
)

REM Step 1: Generate SWIG Java code
echo.
echo [3/6] Generating SWIG Java code...
set "JAVA_SRC_DIR=%WORKSPACE%\quantlib4j-java\src\main\java"

if not exist "%JAVA_SRC_DIR%" mkdir "%JAVA_SRC_DIR%" 2>nul
cd /d "%SWIG_DIR%\SWIG"

swig -c++ -java ^
    -package "%JAVA_PACKAGE%" ^
    -outdir "%JAVA_SRC_DIR%" ^
    -o quantlib_wrap.cpp ^
    quantlib.i

if errorlevel 1 (
    echo ERROR: SWIG generation failed
    exit /b 1
)

dir /b "%JAVA_SRC_DIR%\*.java" >nul 2>&1
set "JAVA_FILE_COUNT=0"
for %%f in ("%JAVA_SRC_DIR%\*.java") do set /a JAVA_FILE_COUNT+=1
echo   OK: Generated %JAVA_FILE_COUNT% Java files

REM Step 2: Build Java module
echo.
echo [4/6] Building Java module...
cd /d "%WORKSPACE%"

call mvn clean install -pl quantlib4j-java -DskipTests -q

if errorlevel 1 (
    echo ERROR: Java module build failed
    exit /b 1
)
echo   OK: Java JAR built

REM Step 3: Build native libraries
echo.
echo [5/6] Building native libraries...

REM Check MSVC
where cl >nul 2>&1
if errorlevel 1 (
    echo   WARNING: MSVC not found - skipping native compilation
    echo   Use build-native.bat for Windows native build
    goto :build_loader
)

REM Check QuantLib
set "QL_INCLUDE="
set "QL_LIB="

if defined QUANTLIB_HOME (
    if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
        set "QL_INCLUDE=%QUANTLIB_HOME%\include"
        set "QL_LIB=%QUANTLIB_HOME%\lib"
    )
)

if not defined QL_LIB if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
        set "QL_INCLUDE=%VCPKG_ROOT%\installed\x64-windows-static\include"
        set "QL_LIB=%VCPKG_ROOT%\installed\x64-windows-static\lib"
    )
)

if not defined QL_LIB (
    echo   WARNING: QuantLib not found - skipping native compilation
    echo   Install with: vcpkg install quantlib:x64-windows-static
    goto :build_loader
)

cd /d "%SWIG_DIR%\SWIG"

REM Compile wrapper (C++17 required)
echo   Compiling wrapper...
cl /c /EHsc /std:c++17 /MD ^
    /I"%JAVA_HOME%\include" ^
    /I"%JAVA_HOME%\include\win32" ^
    /I"%QL_INCLUDE%" ^
    quantlib_wrap.cpp /Fo:quantlib_wrap.obj

if errorlevel 1 (
    echo   ERROR: Wrapper compilation failed
    exit /b 1
)

REM Link
echo   Linking native library...
link /DLL /OUT:quantlib4j.dll ^
    /LIBPATH:"%QL_LIB%" ^
    quantlib_wrap.obj QuantLib-x64-mt-s.lib

if errorlevel 1 (
    echo   ERROR: Native library linking failed
    exit /b 1
)

if not exist "quantlib4j.dll" (
    echo   ERROR: Native library not found after build
    exit /b 1
)

REM Copy to native module
if not exist "%WORKSPACE%\quantlib4j-native-windows\src\main\resources" ^
    mkdir "%WORKSPACE%\quantlib4j-native-windows\src\main\resources" 2>nul

copy /y quantlib4j.dll "%WORKSPACE%\quantlib4j-native-windows\src\main\resources\" >nul
echo   OK: Windows native library built

REM Build Windows native JAR
call mvn clean install -pl quantlib4j-native-windows -DskipTests -q
if errorlevel 1 (
    echo   ERROR: Windows native JAR build failed
    exit /b 1
)
echo   OK: Windows native JAR built and deployed

:build_loader

REM Step 4: Build loader module
echo.
echo [6/6] Building loader module...
cd /d "%WORKSPACE%"

call mvn clean install -pl quantlib4j-loader -DskipTests -q

if errorlevel 1 (
    echo ERROR: Loader module build failed
    exit /b 1
)
echo   OK: Loader JAR built

REM Step 5: Deploy to Nexus
echo.
echo ==============================================
echo [Deploy] Publishing to Nexus
echo ==============================================

if "%DO_DEPLOY%"=="false" (
    echo SKIP: Deploy skipped (credentials not set)
    goto :cleanup
)

cd /d "%WORKSPACE%\quantlib4j-parent"

echo Deploying artifacts...
call mvn deploy -DskipTests -s "%MAVEN_SETTINGS%" -P release

if errorlevel 1 (
    echo ERROR: Deploy failed
    exit /b 1
)

echo.
echo ==============================================
echo   Deploy Complete!
echo ==============================================
echo.
echo Artifacts deployed to Nexus:
echo   https://lb.luopc.com/nexus/
echo.
echo Maven dependency:
echo   ^<dependency^>
echo     ^<groupId^>com.luopc.platform.quantlib^</groupId^
echo     ^<artifactId^>quantlib4j^</artifactId^
echo     ^<version^>%PROJECT_VERSION%^</version^
echo   ^</dependency^>

:cleanup
if exist "%MAVEN_SETTINGS%" del /q "%MAVEN_SETTINGS%" 2>nul

echo.
echo Build complete!
endlocal
exit /b 0
