@echo off
setlocal enabledelayedexpansion

REM Variables
set INSTALL_DIR=C:\WazuhPerformance
set SERVICE_NAME=WazuhPerformanceMonitor

echo === Wazuh Performance Monitor Uninstallation ===

REM Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator!
    pause
    exit /b 1
)

REM Stop and remove service
echo Stopping service...
sc stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 /nobreak >nul

echo Removing service...
sc delete "%SERVICE_NAME%" >nul 2>&1

if exist "%INSTALL_DIR%\nssm.exe" (
    "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm >nul 2>&1
)

REM Kill any running PowerShell processes
taskkill /f /im powershell.exe /fi "WINDOWTITLE eq *service_runner*" >nul 2>&1
timeout /t 3 /nobreak >nul

REM Remove installation directory
echo Removing installation directory...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" >nul 2>&1

echo.
echo === Uninstallation Complete ===
echo.
echo NOTE: Remember to remove the localfile configuration from ossec.conf
echo.
pause
