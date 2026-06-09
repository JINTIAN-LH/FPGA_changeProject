@echo off
setlocal enabledelayedexpansion
:: ============================================================================
:: FPGA Exchange Serdes — One-Click Programming
:: Double-click this file to program the FPGA with the latest bitstream.
:: Prerequisite: Vivado 2019.1+ installed (C:\Xilinx\Vivado or PATH).
:: ============================================================================

title FPGA Exchange Serdes — Program Device

set SCRIPT_DIR=%~dp0
set TCL=%SCRIPT_DIR%fpga_side\scripts\vivado\program_device.tcl

if not exist "%TCL%" (
    echo [ERROR] Script not found: %TCL%
    echo Please run this .bat from the repository root.
    pause
    exit /b 1
)

:: --- locate Vivado ----------------------------------------------------------
set VIVADO=
:: 1) vivado in PATH
where vivado >nul 2>&1
if %ERRORLEVEL% equ 0 set "VIVADO=vivado"

:: 2) scan C:\Xilinx\Vivado for latest version
if "%VIVADO%"=="" if exist "C:\Xilinx\Vivado" (
    for /f "delims=" %%d in ('dir /b /ad /o-n "C:\Xilinx\Vivado" 2^>nul') do (
        if exist "C:\Xilinx\Vivado\%%d\bin\vivado.bat" (
            set "VIVADO=C:\Xilinx\Vivado\%%d\bin\vivado.bat"
            goto :found
        )
    )
)

if "%VIVADO%"=="" (
    echo [ERROR] Vivado not found.
    echo Install Vivado or add its bin\ directory to your PATH.
    pause
    exit /b 1
)

:found
echo ============================================================
echo  FPGA Exchange Serdes — Program Device
echo ============================================================
echo Vivado : %VIVADO%
echo Script : %TCL%
echo.

call "%VIVADO%" -mode batch -source "%TCL%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================
    echo  Done — FPGA programmed successfully.
    echo ============================================================
) else (
    echo.
    echo ============================================================
    echo  Programming FAILED (exit code %ERRORLEVEL%).
    echo ============================================================
)

pause
