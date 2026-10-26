@echo off
setlocal
title OneClick Shutdown

echo.
echo  =========================================
echo          OneClick Shutdown
echo  =========================================
echo.
echo This utility will ask apps to close, clean
echo temporary files, and then shut down Windows.
echo.
echo Save your work before continuing.
echo.
choice /C YN /N /M "Continue? [Y/N]: "
if errorlevel 2 (
    echo.
    echo Cancelled. Nothing was started.
    pause
    exit /b 0
)

set "ENGINE=%~dp0scripts\ShutdownEngine.ps1"
if not exist "%ENGINE%" (
    echo.
    echo ERROR: PowerShell engine was not found:
    echo "%ENGINE%"
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%"
set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
    echo OneClick Shutdown finished with exit code %EXITCODE%.
) else (
    echo OneClick Shutdown has finished.
)
pause
exit /b %EXITCODE%
