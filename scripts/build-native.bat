@echo off
REM build-native.bat - Build QuantLib4J Native Library on Windows
REM Usage: build-native.bat [OPTIONS]
REM
REM Options:
REM   --skip-deps   Skip installing dependencies
REM   --skip-swig   Skip SWIG generation
REM   --skip-build  Skip native library compilation
REM   --swig-dir    SWIG source directory
REM   --help        Show this help

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."
set "JAVA_PACKAGE=com.luopc.platform.quantlib"
set "PROJECT_VERSION=1.42.0-SNAPSHOT"
set "QUANTLIB_VERSION=1.42"

REM Default values
set "SKIP_DEPS=false"
set "SKIP_SWIG=false"
set "SKIP_BUILD=false"
set "SWIG_DIR="

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--skip-deps" set "SKIP_DEPS=true" & shift & goto :parse_args
if /i "%~1"=="--skip-swig" set "SKIP_SWIG=true" & shift & goto :parse_args
if /i "%~1"=="--skip-build" set "SKIP_BUILD=true" & shift & goto :parse_args
if /i "%~1"=="--swig-dir" set "SWIG_DIR=%~2" & shift & shift & goto :parse_args
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args

:args_done

REM Auto-detect directories (parent of quantlib4j-parent is the workspace)
for %%i in ("%WORKSPACE%") do set "WORKSPACE=%%~fi"
set "WORKSPACE_PARENT=%WORKSPACE%\.."

echo ==============================================
echo   QuantLib4J Native Build (Windows)
echo ==============================================
echo Workspace:         %WORKSPACE%
echo Workspace Parent:  %WORKSPACE_PARENT%
echo QuantLib Version:  %QUANTLIB_VERSION%
echo Java Package:     %JAVA_PACKAGE%
echo Project Version:  %PROJECT_VERSION%
echo ==============================================

REM Check prerequisites
echo.
echo [Prerequisites] Checking required tools...

REM Java
where java >nul 2>&1
if errorlevel 1 (
    echo ERROR: Java not found. Please install JDK 21+
    exit /b 1
)
echo   OK: Java found

REM Maven
where mvn >nul 2>&1
if errorlevel 1 (
    echo ERROR: Maven not found. Please install Maven 3.9+
    exit /b 1
)
echo   OK: Maven found

REM SWIG
where swig >nul 2>&1
if errorlevel 1 (
    if exist "%WORKSPACE_PARENT%\swig-4.4.1" (
        echo   WARN: SWIG not in PATH, will use from swig-4.4.1
        set "SWIG_CMD=%WORKSPACE_PARENT%\swig-4.4.1\preinst-swig.exe"
    ) else (
        echo ERROR: SWIG not found. Run: choco install swig
        exit /b 1
    )
) else (
    set "SWIG_CMD=swig"
)
echo   OK: SWIG found

REM Step 1: Install dependencies
if "%SKIP_DEPS%"=="false" goto :skip_deps
echo.
echo [1/5] Installing dependencies...

REM Check Visual Studio
where cl >nul 2>&1
if errorlevel 1 (
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC" (
        echo   OK: Visual Studio 2022 Build Tools found
        echo   NOTE: Run vcvarsall.bat to set environment
    ) else (
        echo WARN: Visual Studio Build Tools not found
        echo   Install from: https://visualstudio.microsoft.com/visual-cpp-build-tools/
    )
)

REM Check vcpkg/QuantLib
if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
    echo   OK: QuantLib found via vcpkg
) else if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
    echo   OK: QuantLib found via QUANTLIB_HOME
) else (
    echo WARN: QuantLib not found
    echo   Install with: vcpkg install quantlib:x64-windows-static
)
:skip_deps

if "%SKIP_DEPS%"=="true" (
    echo.
    echo [1/5] Skipping dependencies (--skip-deps)
)

REM Step 2: Build SWIG (if needed)
where swig >nul 2>&1
if not errorlevel 1 goto :swig_found

echo.
echo [2/5] Building SWIG from source...
if not exist "%WORKSPACE_PARENT%\swig-4.4.1" (
    if exist "%WORKSPACE_PARENT%\swig-4.4.1.tar.gz" (
        echo Extracting SWIG...
        tar -xf "%WORKSPACE_PARENT%\swig-4.4.1.tar.gz" -C "%WORKSPACE_PARENT%"
    ) else (
        echo ERROR: swig-4.4.1 source not found
        exit /b 1
    )
)

set "SWIG_BUILD_DIR=%WORKSPACE_PARENT%\swig-4.4.1\build"
if not exist "%SWIG_BUILD_DIR%" mkdir "%SWIG_BUILD_DIR%"
cd /d "%SWIG_BUILD_DIR%"
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
if errorlevel 1 (
    echo ERROR: SWIG build failed
    exit /b 1
)
set "SWIG_CMD=%SWIG_BUILD_DIR%\Release\swig.exe"
echo OK: SWIG built
:swig_found

REM Step 3: Build QuantLib (if needed)
echo.
echo [3/5] Checking QuantLib...

set "QL_FOUND="
set "QL_INCLUDE="
set "QL_LIB="

if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_INCLUDE=%VCPKG_ROOT%\installed\x64-windows-static\include"
    set "QL_LIB=%VCPKG_ROOT%\installed\x64-windows-static\lib"
    echo   OK: QuantLib found via vcpkg
) else if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_INCLUDE=%QUANTLIB_HOME%\include"
    set "QL_LIB=%QUANTLIB_HOME%\lib"
    echo   OK: QuantLib found via QUANTLIB_HOME
) else if exist "D:\dev-path\vcpkg\installed\x64-windows-static\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_INCLUDE=D:\dev-path\vcpkg\installed\x64-windows-static\include"
    set "QL_LIB=D:\dev-path\vcpkg\installed\x64-windows-static\lib"
    echo   OK: QuantLib found via D:\dev-path\vcpkg
) else if exist "%WORKSPACE_PARENT%\QuantLib-1.42\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_INCLUDE=%WORKSPACE_PARENT%\QuantLib-1.42\include"
    set "QL_LIB=%WORKSPACE_PARENT%\QuantLib-1.42\lib"
    echo   OK: QuantLib found in workspace
)

REM QuantLib include path is "ql" not "quantlib"
if exist "%WORKSPACE_PARENT%\QuantLib-1.42\ql" (
    set "QL_FOUND=1"
    set "QL_INCLUDE=%WORKSPACE_PARENT%\QuantLib-1.42"
    set "QL_LIB=%WORKSPACE_PARENT%\QuantLib-1.42\lib"
    echo   OK: QuantLib found in workspace
)

REM Step 4: Generate SWIG Java bindings
if "%SKIP_SWIG%"=="true" goto :skip_swig
echo.
echo [4/5] Generating SWIG Java bindings...

REM Find QuantLib-SWIG
if not "%SWIG_DIR%"=="" goto :use_swig_dir
if exist "%WORKSPACE_PARENT%\QuantLib-SWIG\SWIG\quantlib.i" (
    set "SWIG_DIR=%WORKSPACE_PARENT%\QuantLib-SWIG"
) else if exist "%WORKSPACE%\..\QuantLib-SWIG\SWIG\quantlib.i" (
    set "SWIG_DIR=%WORKSPACE%\..\QuantLib-SWIG"
) else (
    echo ERROR: QuantLib-SWIG not found
    echo Please clone: git clone git@github.com:luopc/QuantLib-SWIG.git ..
    exit /b 1
)
:use_swig_dir

REM Create output directory
if not exist "%WORKSPACE%\quantlib4j-java\src\main\java" mkdir "%WORKSPACE%\quantlib4j-java\src\main\java"

REM Generate SWIG
cd /d "%SWIG_DIR%\SWIG"
"%SWIG_CMD%" -c++ -java ^
    -package "%JAVA_PACKAGE%" ^
    -outdir "%WORKSPACE%\quantlib4j-java\src\main\java" ^
    -o quantlib_wrap.cpp ^
    quantlib.i

if errorlevel 1 (
    echo ERROR: SWIG generation failed
    exit /b 1
)
echo OK: SWIG bindings generated
:skip_swig

REM Step 5: Build native library
if "%SKIP_BUILD%"=="true" goto :skip_build
echo.
echo [5/5] Building native library...

REM Install parent POM
echo Installing parent POM...
cd /d "%WORKSPACE%"
call mvn install -N -DskipTests -q
if errorlevel 1 (
    echo ERROR: Parent POM install failed
    exit /b 1
)

REM Build quantlib4j-java
echo Building quantlib4j-java...
call mvn clean install -pl quantlib4j-java -DskipTests -q
if errorlevel 1 (
    echo ERROR: quantlib4j-java build failed
    exit /b 1
)

REM Check MSVC environment
where cl >nul 2>&1
if errorlevel 1 (
    echo WARN: MSVC not in PATH. Please run vcvarsall.bat first:
    echo   "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
    echo Skipping native compilation...
    goto :build_done
)

REM Compile native library
echo Compiling quantlib4j.dll...

set "NATIVE_RESOURCES=%WORKSPACE%\quantlib4j-native-windows\src\main\resources"
if not exist "%NATIVE_RESOURCES%" mkdir "%NATIVE_RESOURCES%"

cd /d "%SWIG_DIR%\SWIG"

REM Compile wrapper
cl /c /EHsc /std:c++17 /MD /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32" /I"%QL_INCLUDE%" quantlib_wrap.cpp /Fo:quantlib_wrap.obj
if errorlevel 1 (
    echo ERROR: Wrapper compilation failed
    exit /b 1
)

REM Link
link /DLL /OUT:"%NATIVE_RESOURCES%\quantlib4j.dll" /LIBPATH:"%QL_LIB%" quantlib_wrap.obj QuantLib-x64-mt-s.lib
if errorlevel 1 (
    echo ERROR: Linking failed
    exit /b 1
)

if not exist "%NATIVE_RESOURCES%\quantlib4j.dll" (
    echo ERROR: DLL not created
    exit /b 1
)
echo OK: quantlib4j.dll created

REM Build quantlib4j-native-windows
echo Building quantlib4j-native-windows...
call mvn clean install -pl quantlib4j-native-windows -DskipTests -q

REM Build quantlib4j-loader
echo Building quantlib4j-loader...
call mvn clean install -pl quantlib4j-loader -DskipTests -q

echo OK: Native library built
:skip_build

:build_done
echo.
echo ==============================================
echo   Build Complete!
echo ==============================================
echo.
echo Artifacts:
if exist "%WORKSPACE%\quantlib4j-java\target\quantlib4j-%PROJECT_VERSION%.jar" (
    echo   Java JAR: quantlib4j-%PROJECT_VERSION%.jar
)
if exist "%WORKSPACE%\quantlib4j-native-windows\target\quantlib4j-native-windows-%PROJECT_VERSION%.jar" (
    echo   Native JAR: quantlib4j-native-windows-%PROJECT_VERSION%.jar
)
if exist "%WORKSPACE%\quantlib4j-loader\target\quantlib4j-loader-%PROJECT_VERSION%.jar" (
    echo   Loader JAR: quantlib4j-loader-%PROJECT_VERSION%.jar
)
echo.
echo Next step:
echo   mvn deploy -DskipTests  'or'
echo   Use these artifacts in your project.
echo.

endlocal
exit /b 0

:show_help
echo Usage: build-native.bat [OPTIONS]
echo.
echo Options:
echo   --skip-deps   Skip installing dependencies
echo   --skip-swig   Skip SWIG generation
echo   --skip-build  Skip native library compilation
echo   --swig-dir    QuantLib-SWIG directory
echo   --help        Show this help
exit /b 0
