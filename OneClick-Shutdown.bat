@echo off
setlocal EnableExtensions
title OneClick Shutdown
color 0B
cd /d "%~dp0"

if not exist "%~dp0scripts\ShutdownEngine.ps1" (
    echo ERROR: scripts\ShutdownEngine.ps1 was not found.
    echo Please extract the complete OneClick-Shutdown folder before running this file.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\ShutdownEngine.ps1"
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    echo.
    echo Starting Windows shutdown...
    shutdown.exe /s /t 0
    exit /b 0
)
if "%RC%"=="10" (
    echo.
    echo Shutdown cancelled. Windows will remain on.
    timeout /t 3 /nobreak >nul
    exit /b 0
)

echo.
echo Preparation did not finish safely (exit code %RC%).
echo Windows will NOT be shut down.
pause
exit /b 1
