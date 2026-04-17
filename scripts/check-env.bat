@echo off
REM
REM check-env.bat - Check QuantLib4J build environment (Windows)
REM
REM Usage:
REM   check-env.bat              # Check all dependencies
REM   check-env.bat /json        # Output in JSON format
REM   check-env.bat /verbose     # Show detailed information
REM
REM Author: Claude
REM Date: 2026-04-12

setlocal enabledelayedexpansion

set "JSON_OUTPUT="
set "VERBOSE="

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/json" (
    set "JSON_OUTPUT=1"
    shift
    goto :parse_args
)
if /i "%~1"=="/verbose" (
    set "VERBOSE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="/?" goto :help
if /i "%~1"=="--help" goto :help
shift
goto :parse_args

:args_done

REM Check if running in JSON mode
if defined JSON_OUTPUT (
    goto :json_output
)

REM ===========================================
REM Text Output Mode
REM ===========================================

goto :text_output

:json_output
echo {
echo   "environment": {
echo     "os": "Windows %OS%",
echo     "arch": "%PROCESSOR_ARCHITECTURE%",
echo     "timestamp": "%DATE% %TIME%"
echo   },
echo   "checks": [

REM Java
call :check_java_json
REM Maven
call :check_maven_json
REM SWIG
call :check_swig_json
REM CMake
call :check_cmake_json
REM MSVC
call :check_msvc_json
REM QuantLib
call :check_quantlib_json

echo   ]
echo }

endlocal
exit /b 0

:text_output
cls
echo.
echo ============================================================================
echo                    QuantLib4J Build Environment Check
echo ============================================================================
echo.
echo System:       Windows %OS%
echo Architecture: %PROCESSOR_ARCHITECTURE%
echo User:         %USERNAME%
echo Date:         %DATE% %TIME%
echo.

echo ---------------------------------------------------------------------------
echo [ Required Components ]
echo ---------------------------------------------------------------------------
echo.

call :check_java
call :check_mvn
call :check_swig

echo.
echo ---------------------------------------------------------------------------
echo [ Optional Components (for native builds) ]
echo ---------------------------------------------------------------------------
echo.

call :check_cmake
call :check_msvc

echo.
echo ---------------------------------------------------------------------------
echo [ QuantLib ]
echo ---------------------------------------------------------------------------
echo.

call :check_quantlib

echo.
echo ---------------------------------------------------------------------------
echo [ Environment Variables ]
echo ---------------------------------------------------------------------------
echo.

if defined JAVA_HOME (
    echo   JAVA_HOME:     %JAVA_HOME%
) else (
    echo   JAVA_HOME:     NOT SET
)

if defined MAVEN_OPTS (
    echo   MAVEN_OPTS:    %MAVEN_OPTS%
) else (
    echo   MAVEN_OPTS:    NOT SET
)

if defined VCPKG_ROOT (
    echo   VCPKG_ROOT:    %VCPKG_ROOT%
) else (
    echo   VCPKG_ROOT:    NOT SET
)

if defined QUANTLIB_HOME (
    echo   QUANTLIB_HOME: %QUANTLIB_HOME%
) else (
    echo   QUANTLIB_HOME: NOT SET
)

echo.
echo ---------------------------------------------------------------------------
echo [ Summary ]
echo ---------------------------------------------------------------------------
echo.

REM Check if all required tools are found
set "ALL_OK=true"
set "NATIVE_OK=true"

where java >nul 2>&1
if errorlevel 1 set "ALL_OK=false"

where mvn >nul 2>&1
if errorlevel 1 set "ALL_OK=false"

where swig >nul 2>&1
if errorlevel 1 set "ALL_OK=false"

REM Check MSVC and QuantLib
set "MSVC_FOUND="
set "QL_FOUND="

REM Check MSVC
for /f "tokens=*" %%i in ('where cl 2^>nul') do (
    set "MSVC_FOUND=1"
)

REM Check VS Build Tools path
if not defined MSVC_FOUND (
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" (
        set "MSVC_FOUND=1"
    )
)

REM Check QuantLib paths
if defined QUANTLIB_HOME (
    if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" set "QL_FOUND=1"
)
if not defined QL_FOUND if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" set "QL_FOUND=1"
)
if not defined QL_FOUND if exist "D:\dev-path\vcpkg\installed\x64-windows-static\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
)

if not defined MSVC_FOUND set "NATIVE_OK=false"
if not defined QL_FOUND set "NATIVE_OK=false"

if "!ALL_OK!"=="true" (
    if "!NATIVE_OK!"=="true" (
        echo   [OK] All components are installed and ready!
        echo.
        echo   Next steps:
        echo     1. Clone QuantLib-SWIG (if not already done)
        echo     2. Run: quick-build.bat
    ) else (
        echo   [PARTIAL] Required tools installed, but native build requires:
        echo.
        echo   Missing for native builds:
        if not defined MSVC_FOUND echo     - Visual Studio Build Tools (run vcvarsall.bat)
        if not defined QL_FOUND echo     - QuantLib library
        echo.
        echo   Next steps:
        if not defined QL_FOUND echo     1. Install QuantLib: vcpkg install quantlib:x64-windows-static
        if not defined MSVC_FOUND echo   2. Run: "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
        echo     3. Run: quick-build.bat
    )
) else (
    echo   [WARNING] Some required tools are missing
    echo.
    echo   To install missing tools:
    echo.
    echo     Java 21:    https://adoptium.net/
    echo     Maven:      https://maven.apache.org/download.cgi
    echo     SWIG:       choco install swig
    echo     CMake:      choco install cmake
    echo     MSVC:       choco install visualstudio2022buildtools
    echo     QuantLib:   vcpkg install quantlib:x64-windows-static
)

echo.
echo ============================================================================

endlocal
exit /b 0

:help
echo Usage: check-env.bat [OPTIONS]
echo.
echo Options:
echo   /json       Output in JSON format
echo   /verbose    Show detailed information
echo   /help       Show this help message
exit /b 0

REM ===========================================
REM Check Functions
REM ===========================================

:check_java
where java >nul 2>&1
if errorlevel 1 (
    echo   [MISSING] [java]      Java JDK 21+
    echo              Please install JDK 21 from https://adoptium.net/
    exit /b 0
)
echo   [FOUND]   [java]      Java JDK 21+
if defined VERBOSE (
    java -version 2>&1 | findstr /i "version"
)
exit /b 0

:check_java_json
where java >nul 2>&1
if errorlevel 1 (
    echo     {"name":"java","status":"error","version":"missing","description":"Java JDK 21+"},
    exit /b 0
)
echo     {"name":"java","status":"ok","version":"found","description":"Java JDK 21+"},
exit /b 0

:check_mvn
where mvn >nul 2>&1
if errorlevel 1 (
    echo   [MISSING] [mvn]       Maven 3.9+
    echo              Please install from https://maven.apache.org/download.cgi
    exit /b 0
)
echo   [FOUND]   [mvn]       Maven 3.9+
if defined VERBOSE (
    mvn -version 2>&1 | findstr /i "apache"
)
exit /b 0

:check_mvn_json
where mvn >nul 2>&1
if errorlevel 1 (
    echo     {"name":"mvn","status":"error","version":"missing","description":"Maven 3.9+"},
    exit /b 0
)
echo     {"name":"mvn","status":"ok","version":"found","description":"Maven 3.9+"},
exit /b 0

:check_swig
where swig >nul 2>&1
if errorlevel 1 (
    echo   [MISSING] [swig]      SWIG 4.2+
    echo              Run: choco install swig
    exit /b 0
)
echo   [FOUND]   [swig]      SWIG 4.2+
if defined VERBOSE (
    swig -version 2>&1 | findstr /i "version"
)
exit /b 0

:check_swig_json
where swig >nul 2>&1
if errorlevel 1 (
    echo     {"name":"swig","status":"error","version":"missing","description":"SWIG 4.2+"},
    exit /b 0
)
echo     {"name":"swig","status":"ok","version":"found","description":"SWIG 4.2+"},
exit /b 0

:check_cmake
where cmake >nul 2>&1
if errorlevel 1 (
    echo   [MISSING] [cmake]     CMake 3.20+ ^(optional^)
    echo              Run: choco install cmake
    exit /b 0
)
echo   [FOUND]   [cmake]     CMake 3.20+
if defined VERBOSE (
    cmake --version 2>&1 | findstr /i "cmake"
)
exit /b 0

:check_cmake_json
where cmake >nul 2>&1
if errorlevel 1 (
    echo     {"name":"cmake","status":"warning","version":"missing","description":"CMake 3.20+ (optional)"},
    exit /b 0
)
echo     {"name":"cmake","status":"ok","version":"found","description":"CMake 3.20+"},
exit /b 0

:check_msvc
REM Check multiple MSVC locations

REM Method 1: Check if cl.exe is in PATH
where cl >nul 2>&1
if not errorlevel 1 (
    echo   [FOUND]   [msvc]      Visual C++ Compiler ^(in PATH^)
    exit /b 0
)

REM Method 2: Check VS Build Tools
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" (
    echo   [FOUND]   [msvc]      Visual Studio 2022 Build Tools ^(not in PATH^)
    if defined VERBOSE (
        echo              Run: "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
    )
    exit /b 0
)

if exist "C:\Program Files\Microsoft Visual Studio\2022\*\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" (
    echo   [FOUND]   [msvc]      Visual Studio 2022 ^(not in PATH^)
    exit /b 0
)

REM Method 3: Check vcvarsall.bat existence
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" (
    echo   [FOUND]   [msvc]      VS Build Tools installed ^(run vcvarsall.bat^)
    echo              To enable: "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
    exit /b 0
)

echo   [MISSING] [msvc]      Visual C++ compiler
echo              Install: choco install visualstudio2022buildtools
echo              Or: https://visualstudio.microsoft.com/visual-cpp-build-tools/
exit /b 0

:check_msvc_json
REM Check if cl.exe is in PATH
where cl >nul 2>&1
if not errorlevel 1 (
    echo     {"name":"msvc","status":"ok","version":"found","description":"Visual C++ Compiler"},
    exit /b 0
)

REM Check VS Build Tools
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" (
    echo     {"name":"msvc","status":"warning","version":"found","description":"VS Build Tools installed (not in PATH)"},
    exit /b 0
)

echo     {"name":"msvc","status":"warning","version":"missing","description":"Visual C++ compiler"},
exit /b 0

:check_quantlib
set "QL_FOUND="
set "QL_VERSION="
set "QL_PATH="

REM Check QUANTLIB_HOME
if defined QUANTLIB_HOME (
    if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
        set "QL_FOUND=1"
        set "QL_PATH=%QUANTLIB_HOME%"
    )
)

REM Check VCPKG_ROOT
if not defined QL_FOUND if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
        set "QL_FOUND=1"
        set "QL_PATH=%VCPKG_ROOT%\installed\x64-windows-static"
    )
    if not defined QL_FOUND if exist "%VCPKG_ROOT%\installed\x64-windows\lib\QuantLib*.lib" (
        set "QL_FOUND=1"
        set "QL_PATH=%VCPKG_ROOT%\installed\x64-windows"
    )
)

REM Check common vcpkg installation path
if not defined QL_FOUND if exist "D:\dev-path\vcpkg\installed\x64-windows-static\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_PATH=D:\dev-path\vcpkg\installed\x64-windows-static"
)
if not defined QL_FOUND if exist "D:\dev-path\vcpkg\installed\x64-windows\lib\QuantLib*.lib" (
    set "QL_FOUND=1"
    set "QL_PATH=D:\dev-path\vcpkg\installed\x64-windows"
)

REM Try pkg-config if available
if not defined QL_FOUND (
    where pkg-config >nul 2>&1
    if not errorlevel 1 (
        pkg-config --exists quantlib 2>nul
        if not errorlevel 1 (
            for /f "tokens=*" %%v in ('pkg-config --modversion quantlib 2^>nul') do set "QL_VERSION=%%v"
            if defined QL_VERSION (
                set "QL_FOUND=1"
            )
        )
    )
)

REM Report result
if defined QL_FOUND (
    if defined QL_VERSION (
        echo   [FOUND]   [quantlib]  QuantLib %QL_VERSION%
    ) else (
        echo   [FOUND]   [quantlib]  QuantLib library
    )
    if defined VERBOSE (
        if defined QL_PATH (
            echo              Path: %QL_PATH%
        )
    )
) else (
    echo   [MISSING] [quantlib]  QuantLib 1.42+
    echo.
    echo              Installation options:
    echo              1. vcpkg:     vcpkg install quantlib:x64-windows-static
    echo              2. Source:    https://www.quantlib.org/install/windows.shtml
)
exit /b 0

:check_quantlib_json
set "QL_FOUND="

if defined QUANTLIB_HOME (
    if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
        echo     {"name":"quantlib","status":"ok","version":"found","description":"QuantLib (%QUANTLIB_HOME%)"},
        exit /b 0
    )
)

if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
        echo     {"name":"quantlib","status":"ok","version":"found","description":"QuantLib (vcpkg static)"},
        exit /b 0
    )
)

if exist "D:\dev-path\vcpkg\installed\x64-windows-static\lib\QuantLib*.lib" (
    echo     {"name":"quantlib","status":"ok","version":"found","description":"QuantLib (vcpkg)"},
    exit /b 0
)

echo     {"name":"quantlib","status":"error","version":"missing","description":"QuantLib 1.42+"},
exit /b 0
