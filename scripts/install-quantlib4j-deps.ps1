# install-quantlib4j-deps.ps1
# Install dependencies for QuantLib4J build on Windows
#
# Usage:
#   .\install-quantlib4j-deps.ps1          # Interactive installation
#   .\install-quantlib4j-deps.ps1 -SkipVerify  # Skip verification
#   .\install-quantlib4j-deps.ps1 -All      # Install all including optional
#
# Requires: PowerShell 5.1+, Chocolatey (recommended)
#
# Author: Claude
# Date: 2026-04-11

param(
    [switch]$SkipVerify,
    [switch]$All,
    [switch]$Quiet,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
}

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $color = $colors[$Type]
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-PathExists {
    param([string]$Path)
    Test-Path $Path
}

function Install-ChocolateyPackage {
    param([string]$PackageName)
    if (Test-Command choco) {
        Write-Status "Installing $PackageName via Chocolatey..." "Info"
        choco install $PackageName -y --no-progress 2>&1 | Out-Null
        return $true
    }
    return $false
}

if ($Help) {
    Write-Host @"
QuantLib4J Dependency Installer for Windows

Usage:
    .\install-quantlib4j-deps.ps1 [OPTIONS]

Options:
    -SkipVerify  Skip environment verification
    -All         Install all dependencies including optional
    -Quiet       Run in quiet mode
    -Help        Show this help

Requirements:
    - PowerShell 5.1+
    - Chocolatey (recommended)

"@
    exit 0
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "            QuantLib4J Dependency Installer for Windows" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""

# Check Chocolatey
Write-Host "[INFO] Checking Chocolatey..." -ForegroundColor Cyan
if (-not (Test-Command choco)) {
    Write-Host "[WARN] Chocolatey not found. Installing..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "[OK] Chocolatey installed. Please restart PowerShell." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Host "[ERROR] Failed to install Chocolatey: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "[OK] Chocolatey found" -ForegroundColor Green
}

# Check Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator. Some installations may fail." -ForegroundColor Yellow
    if (-not $Quiet) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            exit 0
        }
    }
}

# Environment Verification
if (-not $SkipVerify) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[ Environment Verification ]" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Command java) {
        Write-Host "[OK] Java: Found" -ForegroundColor Green
    }
    else {
        Write-Host "[MISSING] Java JDK 21+ not found" -ForegroundColor Red
    }

    if (Test-Command mvn) {
        Write-Host "[OK] Maven: Found" -ForegroundColor Green
    }
    else {
        Write-Host "[MISSING] Maven not found" -ForegroundColor Red
    }
}

# Install SWIG
Write-Host ""
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "[ Installing SWIG ]" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

if (Test-Command swig) {
    Write-Host "[OK] SWIG already installed" -ForegroundColor Green
}
else {
    if (Install-ChocolateyPackage "swig") {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Test-Command swig) {
            Write-Host "[OK] SWIG installed" -ForegroundColor Green
        }
        else {
            Write-Host "[ERROR] SWIG installation failed" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[WARN] Chocolatey not available. Install SWIG manually:" -ForegroundColor Yellow
        Write-Host "       https://sourceforge.net/projects/swig/files/" -ForegroundColor Yellow
    }
}

# Install CMake (Optional)
if ($All) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[ Installing CMake ]" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Command cmake) {
        Write-Host "[OK] CMake already installed" -ForegroundColor Green
    }
    else {
        if (Install-ChocolateyPackage "cmake") {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Test-Command cmake) {
                Write-Host "[OK] CMake installed" -ForegroundColor Green
            }
        }
    }
}

# Install Visual Studio Build Tools (Optional)
if ($All) {
    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[ Installing Visual Studio Build Tools ]" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Command cl) {
        Write-Host "[OK] MSVC compiler found" -ForegroundColor Green
    }
    else {
        Write-Host "Installing Visual Studio Build Tools..." -ForegroundColor Yellow
        $vsBootstrapper = "$env:TEMP\vs_BuildTools.exe"
        $vsUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"

        try {
            Write-Host "Downloading Visual Studio Build Tools..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $vsUrl -OutFile $vsBootstrapper -UseBasicParsing
            Write-Host "Installing... (this may take 10-20 minutes)" -ForegroundColor Cyan
            Start-Process -Wait -FilePath $vsBootstrapper -ArgumentList "--quiet", "--wait", "--norestart", "--nocache", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "--add", "Microsoft.VisualStudio.Component.Windows11SDK.22621"
            Remove-Item $vsBootstrapper -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Visual Studio Build Tools installed" -ForegroundColor Green
            Write-Host "[INFO] Please restart PowerShell to use MSVC compiler" -ForegroundColor Cyan
        }
        catch {
            Write-Host "[ERROR] Failed to install: $_" -ForegroundColor Red
            Write-Host "[INFO] Download manually: https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Yellow
        }
    }
}

# Install QuantLib
Write-Host ""
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "[ Installing QuantLib ]" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$quantlibFound = $false
$quantlibPaths = @(
    "$env:QUANTLIB_HOME\lib\QuantLib.lib",
    "C:\vcpkg\installed\x64-windows\lib\QuantLib.lib"
)

foreach ($path in $quantlibPaths) {
    if (Test-PathExists $path) {
        Write-Host "[OK] QuantLib found at: $path" -ForegroundColor Green
        $quantlibFound = $true
        break
    }
}

if (-not $quantlibFound) {
    Write-Host "QuantLib not installed. Please choose an installation method:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Option 1: vcpkg (recommended)"
    Write-Host "    git clone https://github.com/microsoft/vcpkg.git C:\vcpkg"
    Write-Host "    C:\vcpkg\bootstrap-vcpkg.bat"
    Write-Host "    C:\vcpkg\vcpkg.exe install quantlib:x64-windows"
    Write-Host ""
    Write-Host "  Option 2: Build from source"
    Write-Host "    See: https://www.quantlib.org/install/windows.shtml"
    Write-Host ""

    if (-not $Quiet) {
        $install = Read-Host "Install vcpkg and QuantLib now? (y/N)"
        if ($install -eq 'y' -or $install -eq 'Y') {
            Write-Host ""
            Write-Host "Installing vcpkg..." -ForegroundColor Cyan

            $vcpkgDir = "C:\vcpkg"
            if (-not (Test-PathExists $vcpkgDir)) {
                Write-Host "Cloning vcpkg..." -ForegroundColor Cyan
                git clone https://github.com/microsoft/vcpkg.git $vcpkgDir 2>&1 | Out-Null
                Write-Host "Bootstrapping vcpkg..." -ForegroundColor Cyan
                Push-Location $vcpkgDir
                & .\bootstrap-vcpkg.bat 2>&1 | Out-Null
                Pop-Location
            }

            $env:VCPKG_ROOT = $vcpkgDir
            [System.Environment]::SetEnvironmentVariable("VCPKG_ROOT", $vcpkgDir, "User")

            Write-Host ""
            Write-Host "Installing QuantLib... (may take 20-40 minutes)" -ForegroundColor Cyan
            & "$vcpkgDir\vcpkg.exe" install quantlib:x64-windows

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] QuantLib installed successfully!" -ForegroundColor Green
            }
            else {
                Write-Host "[ERROR] QuantLib installation failed" -ForegroundColor Red
            }
        }
    }
}

# Summary
Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "                               Summary" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Installed/Updated:" -ForegroundColor Green
if (Test-Command swig) { Write-Host "  [OK] SWIG" -ForegroundColor Green }
if ($All) {
    if (Test-Command cmake) { Write-Host "  [OK] CMake" -ForegroundColor Green }
    if (Test-Command cl) { Write-Host "  [OK] MSVC" -ForegroundColor Green }
}

Write-Host ""
Write-Host "Manual steps required:" -ForegroundColor Yellow
if (-not (Test-Command swig)) {
    Write-Host "  - Install SWIG: https://sourceforge.net/projects/swig/files/" -ForegroundColor Gray
}
if (-not $quantlibFound) {
    Write-Host "  - Install QuantLib: vcpkg install quantlib:x64-windows" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell (to refresh environment)" -ForegroundColor Gray
Write-Host "  2. Run: .\check-env.bat" -ForegroundColor Gray
Write-Host "  3. Run: .\quick-build.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
