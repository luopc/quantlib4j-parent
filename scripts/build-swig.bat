@echo off
REM build-swig.bat - Generate SWIG Java code on Windows
REM Usage: build-swig.bat [SWIG_DIR] [OUTPUT_DIR]

setlocal

set "SWIG_DIR=%~1"
if "%SWIG_DIR%"=="" set "SWIG_DIR=%CD%\..\..\QuantLib-SWIG"

set "OUTPUT_DIR=%~2"
if "%OUTPUT_DIR%"=="" set "OUTPUT_DIR=%CD%\..\quantlib4j-java\src\main\java"

set "JAVA_PACKAGE=com.luopc.platform.quantlib"
set "MODULE_NAME=quantlib4j"

echo === QuantLib SWIG Java Code Generator ===
echo SWIG Directory: %SWIG_DIR%
echo Output Directory: %OUTPUT_DIR%
echo Package: %JAVA_PACKAGE%

cd /d "%SWIG_DIR%\SWIG"

echo Generating Java code...
swig -c++ -java ^
    -package "%JAVA_PACKAGE%" ^
    -outdir "%OUTPUT_DIR%" ^
    -o quantlib_wrap.cpp ^
    quantlib.i

echo Java code generated successfully!
dir /b "%OUTPUT_DIR%"

endlocal
