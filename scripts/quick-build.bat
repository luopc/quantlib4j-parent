@echo off
REM quick-build.bat - QuantLib4J Quick Build Script (Windows)
REM Usage: quick-build.bat [QuantLib-SWIG-path]

setlocal enabledelayedexpansion

set "VERSION=1.42"
set "PACKAGE=com.luopc.platform.quantlib"

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "WORKSPACE=%SCRIPT_DIR%.."

REM QuantLib-SWIG path
if "%~1"=="" (
    set "QUANTLIB_SWIG=%WORKSPACE%\..\QuantLib-SWIG"
) else (
    set "QUANTLIB_SWIG=%~1"
)

REM Output directories
set "JAVA_SRC=%WORKSPACE%\quantlib4j-java\src\main\java\com\luopc\platform\quantlib"
set "JAVA_TARGET=%WORKSPACE%\quantlib4j-java\target"

echo ========================================
echo   QuantLib4J Quick Build Script
echo ========================================
echo Version:       %VERSION%
echo Package:       %PACKAGE%
echo SWIG Source:   %QUANTLIB_SWIG%
echo Output:        %JAVA_TARGET%
echo.

REM Check QuantLib-SWIG
if not exist "%QUANTLIB_SWIG%\SWIG\quantlib.i" (
    echo ERROR: QuantLib-SWIG not found at: %QUANTLIB_SWIG%
    echo    Please specify path: quick-build.bat D:\path\to\QuantLib-SWIG
    exit /b 1
)

REM 1. Clean
echo [Step 1] Clean previous build
if exist "%WORKSPACE%\quantlib4j-java\src\main\java\*.java" del /q "%WORKSPACE%\quantlib4j-java\src\main\java\*.java" 2>nul
if exist "%WORKSPACE%\quantlib4j-java\src\main\java\*.h" del /q "%WORKSPACE%\quantlib4j-java\src\main\java\*.h" 2>nul
if exist "%JAVA_SRC%\*.java" del /q "%JAVA_SRC%\*.java" 2>nul
if exist "%JAVA_SRC%\*.h" del /q "%JAVA_SRC%\*.h" 2>nul
if exist "%JAVA_TARGET%" rmdir /s /q "%JAVA_TARGET%" 2>nul
if not exist "%JAVA_SRC%" mkdir "%JAVA_SRC%" 2>nul
mkdir "%JAVA_TARGET%" 2>nul
echo OK: Cleaned
echo.

REM 2. SWIG Generate
echo [Step 2] Generate Java code from SWIG
cd /d "%QUANTLIB_SWIG%\SWIG"

swig -c++ -java -package "%PACKAGE%" -outdir "%JAVA_SRC%" -o quantlib_wrap.cpp quantlib.i

if errorlevel 1 (
    echo ERROR: SWIG failed
    exit /b 1
)

REM Count generated files
set "JAVA_COUNT=0"
for /r "%JAVA_SRC%" %%f in (*.java) do set /a JAVA_COUNT+=1
echo OK: Generated %JAVA_COUNT% Java files
echo.

REM 3. Compile Java
echo [Step 3] Compile Java
mkdir "%JAVA_TARGET%\classes" 2>nul
dir /s /b "%JAVA_SRC%\*.java" > "%JAVA_TARGET%\sources.txt"

REM Try to find javac if JAVA_HOME not set
if "%JAVA_HOME%"=="" (
    where javac >nul 2>&1
    if not errorlevel 1 (
        set "JAVAC=javac"
    ) else (
        echo ERROR: javac not found. Set JAVA_HOME or add javac to PATH.
        exit /b 1
    )
) else (
    if not exist "%JAVA_HOME%\bin\javac.exe" (
        echo ERROR: javac not found at %JAVA_HOME%\bin\javac.exe
        exit /b 1
    )
    set "JAVAC=%JAVA_HOME%\bin\javac"
)

%JAVAC% -d "%JAVA_TARGET%\classes" @"%JAVA_TARGET%\sources.txt"

if errorlevel 1 (
    echo ERROR: Java compilation failed
    exit /b 1
)

cd /d "%JAVA_TARGET%\classes"
jar cf "..\quantlib4j-%VERSION%.jar" com
echo OK: Java JAR created: quantlib4j-%VERSION%.jar
echo.

REM 4. Compile native library (optional)
echo [Step 4] Compile native library (Windows)

REM Check MSVC
where cl >nul 2>&1
if errorlevel 1 (
    echo WARN: MSVC not found - skipping native compilation
    goto :summary
)

REM Check QuantLib
set "QL_LIB="
if exist "%QUANTLIB_HOME%\lib\QuantLib*.lib" (
    set "QL_INCLUDE=%QUANTLIB_HOME%\include"
    set "QL_LIB=%QUANTLIB_HOME%\lib"
) else (
    if exist "%VCPKG_ROOT%\installed\x64-windows-static\lib\QuantLib*.lib" (
        set "QL_INCLUDE=%VCPKG_ROOT%\installed\x64-windows-static\include"
        set "QL_LIB=%VCPKG_ROOT%\installed\x64-windows-static\lib"
    ) else (
        echo WARN: QuantLib not found - skipping native compilation
        goto :summary
    )
)

cd /d "%QUANTLIB_SWIG%\SWIG"

REM Compile wrapper (use /MT to match QuantLib's static runtime library)
cl /c /EHsc /std:c++17 /MT /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32" /I"%QL_INCLUDE%" quantlib_wrap.cpp /Fo:quantlib_wrap.obj

if errorlevel 1 (
    echo ERROR: Wrapper compilation failed
    exit /b 1
)

REM Link
link /DLL /OUT:quantlib4j.dll /LIBPATH:"%QL_LIB%" quantlib_wrap.obj QuantLib-x64-mt-s.lib

if not exist "quantlib4j.dll" (
    echo ERROR: Native library compilation failed
    exit /b 1
)

echo OK: Native library created: quantlib4j.dll
echo.

REM 5. Package native JAR
echo [Step 5] Package native JAR
copy quantlib4j.dll "%JAVA_TARGET%\" >nul
cd /d "%JAVA_TARGET%"
jar cf "quantlib4j-%VERSION%-windows-x64.jar" quantlib4j.dll
echo OK: Native JAR created: quantlib4j-%VERSION%-windows-x64.jar
echo.

REM 6. Install to local Maven
echo [Step 6] Install to local Maven repository
call mvn install:install-file -Dfile="quantlib4j-%VERSION%.jar" -DgroupId=com.luopc.platform.quantlib -DartifactId=quantlib4j -Dversion=%VERSION% -Dpackaging=jar

if exist "quantlib4j-%VERSION%-windows-x64.jar" (
    call mvn install:install-file -Dfile="quantlib4j-%VERSION%-windows-x64.jar" -DgroupId=com.luopc.platform.quantlib -DartifactId=quantlib4j -Dversion=%VERSION% -Dpackaging=jar -Dclassifier=windows-x64
)

echo OK: Installed to local Maven
echo.

REM Cleanup
del /q "%JAVA_TARGET%\sources.txt" 2>nul
del /q "%QUANTLIB_SWIG%\SWIG\quantlib_wrap.cpp" 2>nul
del /q "%QUANTLIB_SWIG%\SWIG\quantlib_wrap.obj" 2>nul

goto :summary

:summary
echo ========================================
echo   Build Summary
echo ========================================
echo OK: Java code generated: %JAVA_COUNT% files
if exist "%JAVA_TARGET%\quantlib4j-%VERSION%.jar" (
    echo OK: Java JAR created: quantlib4j-%VERSION%.jar
) else (
    echo FAIL: Java JAR: Failed
)
if exist "%JAVA_TARGET%\quantlib4j-%VERSION%-windows-x64.jar" (
    echo OK: Native JAR created: quantlib4j-%VERSION%-windows-x64.jar
) else (
    echo WARN: Native JAR: Skipped
)
echo.
echo Next steps:
echo   1. Add dependency to valuation-service pom.xml
echo   2. Build: mvn clean install -pl valuation-service -am
echo.
echo Maven dependency:
echo   ^<dependency^>
echo     ^<groupId^>com.luopc.platform.quantlib^</groupId^>
echo     ^<artifactId^>quantlib4j^</artifactId^>
echo     ^<version^>%VERSION%^</version^>
echo   ^</dependency^>

endlocal
