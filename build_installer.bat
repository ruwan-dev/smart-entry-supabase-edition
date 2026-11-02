@echo off
title Building Smart Entry v1.0.1 Installer
echo ===============================================
echo   Building Smart Entry v1.0.1 Installer
echo ===============================================
echo.

echo [1/3] Compiling Flutter Windows Release binaries...
call "C:\src\flutter\bin\flutter.bat" build windows --release
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Compiling Inno Setup Installer...
set ISCC="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="C:\Program Files\Inno Setup 6\ISCC.exe"

%ISCC% smart_entry_installer.iss
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Inno Setup compilation failed!
    pause
    exit /b %errorlevel%
)

echo.
echo ===============================================
echo   [SUCCESS] Installer Generated Successfully!
echo   Location: Installer\SmartEntry_Setup_v1.0.1.exe
echo ===============================================
pause
