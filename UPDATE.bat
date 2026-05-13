@echo off
title BillMed - Build & Update
cd /d "%~dp0"

echo ================================================
echo       BillMed - Build & Update
echo ================================================
echo.

git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Git not found. Install: https://git-scm.com/downloads
    pause
    exit /b
)

setlocal enabledelayedexpansion

for /f "tokens=2 delims=: " %%a in ('findstr "^version:" pubspec.yaml') do set FULL_VER=%%a
for /f "tokens=1 delims=+" %%a in ("!FULL_VER!") do set VER=%%a
for /f "tokens=2 delims=+" %%a in ("!FULL_VER!") do set BUILD=%%a
if "!BUILD!"=="" set BUILD=1
set /a NEW_BUILD=BUILD+1

echo Current: v!VER!+!BUILD!
echo.
echo Options:
echo   1. Push code + bump version + GitHub Actions builds APK
echo   2. Local build ONLY (no push)
echo   3. Cancel
echo.
set /p opt="Choice (1/2/3): "

if "!opt!"=="3" exit /b

if "!opt!"=="1" (
    powershell -Command "(Get-Content pubspec.yaml) -replace 'version: !FULL_VER!', 'version: !VER!+!NEW_BUILD!' | Set-Content pubspec.yaml"
    git add -A
    git commit -m "Update v!VER!+!NEW_BUILD!"
    if !errorlevel! neq 0 ( echo Commit failed! & pause & exit /b )
    git push
    echo.
    echo ================================================
    echo     PUSHED TO GITHUB!
    echo ================================================
    echo.
    echo GitHub Actions will build APK (~10 min).
    echo.
    echo Download link for phone:
    echo https://github.com/krsnaSuraj/BillMed/releases/latest
    pause
    exit /b
)

if "!opt!"=="2" (
    echo.
    echo Building locally...
    call flutter pub get
    if !errorlevel! neq 0 ( echo pub get failed! & pause & exit /b )
    call dart run build_runner build --delete-conflicting-outputs
    if !errorlevel! neq 0 ( echo build_runner failed! & pause & exit /b )
    call flutter build apk --release --obfuscate --split-debug-info=debug-info
    if !errorlevel! neq 0 ( echo APK build failed! & pause & exit /b )
    echo.
    echo ================================================
    echo     BUILD SUCCESSFUL!
    echo ================================================
    echo.
    echo APK: %~dp0build\app\outputs\flutter-apk\app-release.apk
    pause
    exit /b
)

echo Invalid choice.
endlocal
pause
