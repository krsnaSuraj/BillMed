@echo off
title BillMed - Build & Update
cd /d "%~dp0"

echo =============================================================================
echo       BillMed - Build & Update Script
echo =============================================================================
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

echo Current version: v!FULL_VER!
echo.
echo =============================================================================
echo OPTIONS:
echo =============================================================================
echo.
echo   [1] Push + MINOR bump (2.4.X) — new features/fixes, triggers APK build
echo   [2] Push + MAJOR bump (X.0.0) — big releases, triggers APK build
echo   [3] Push + BUILD bump (x.x.X+1) — same release, NO new APK
echo   [4] Local build ONLY (install via USB / share APK)
echo   [5] Local build + Install on phone via USB
echo   [6] Cancel
echo.
set /p opt="Enter choice (1-6): "

if "!opt!"=="6" exit /b

REM ===== OPTION 1: Minor version bump =====
if "!opt!"=="1" (
    for /f "tokens=1,2 delims=." %%a in ("!VER!") do set MAJOR=%%a & set MINOR=%%b
    set /a NEW_MINOR=MINOR+1
    set NEW_VER=!MAJOR!.!NEW_MINOR!.0
    powershell -Command "(Get-Content pubspec.yaml) -replace 'version: !FULL_VER!', 'version: !NEW_VER!+1' | Set-Content pubspec.yaml"
    powershell -Command "(Get-Content android\local.properties) -replace 'flutter.versionName=!VER!', 'flutter.versionName=!NEW_VER!' | Set-Content android\local.properties"
    powershell -Command "(Get-Content android\local.properties) -replace 'flutter.versionCode=!BUILD!', 'flutter.versionCode=1' | Set-Content android\local.properties"
    echo.
    echo Bumped to v!NEW_VER!+1
    call :_commit_and_push "Bump v!NEW_VER! - minor release"
    goto :eof
)

REM ===== OPTION 2: Major version bump =====
if "!opt!"=="2" (
    set /a NEW_MAJOR=VER
    set /a NEW_MAJOR+=1
    set NEW_VER=!NEW_MAJOR!.0.0
    powershell -Command "(Get-Content pubspec.yaml) -replace 'version: !FULL_VER!', 'version: !NEW_VER!+1' | Set-Content pubspec.yaml"
    powershell -Command "(Get-Content android\local.properties) -replace 'flutter.versionName=!VER!', 'flutter.versionName=!NEW_VER!' | Set-Content android\local.properties"
    powershell -Command "(Get-Content android\local.properties) -replace 'flutter.versionCode=!BUILD!', 'flutter.versionCode=1' | Set-Content android\local.properties"
    echo.
    echo Bumped to v!NEW_VER!+1
    call :_commit_and_push "Bump v!NEW_VER! - major release"
    goto :eof
)

REM ===== OPTION 3: Build number bump only (no new release) =====
if "!opt!"=="3" (
    set /a NEW_BUILD=BUILD+1
    powershell -Command "(Get-Content pubspec.yaml) -replace 'version: !FULL_VER!', 'version: !VER!+!NEW_BUILD!' | Set-Content pubspec.yaml"
    if "!VER!"=="!FULL_VER!" (
        powershell -Command "(Get-Content android\local.properties) -replace 'flutter.versionCode=!BUILD!', 'flutter.versionCode=!NEW_BUILD!' | Set-Content android\local.properties"
    )
    echo.
    echo Bumped to v!VER!+!NEW_BUILD! (build only)
    call :_commit_and_push "Update v!VER!+!NEW_BUILD!"
    goto :eof
)

REM ===== OPTION 4: Local build only =====
if "!opt!"=="4" (
    echo.
    echo Building locally...
    call flutter pub get
    if !errorlevel! neq 0 ( echo pub get failed! & pause & exit /b )
    call dart run build_runner build --delete-conflicting-outputs
    if !errorlevel! neq 0 ( echo build_runner failed! & pause & exit /b )
    call flutter build apk --release --obfuscate --split-debug-info=debug-info
    if !errorlevel! neq 0 ( echo APK build failed! & pause & exit /b )
    echo.
    echo =============================================================================
    echo     BUILD SUCCESSFUL!
    echo =============================================================================
    echo.
    echo APK: %~dp0build\app\outputs\flutter-apk\app-release.apk
    echo Size:
    for %%f in ("%~dp0build\app\outputs\flutter-apk\app-release.apk") do echo     %%~zf bytes
    echo.
    echo Next steps:
    echo   - Install on phone via USB:   flutter install
    echo   - Share APK via WhatsApp:     send the APK file from explorer
    pause
    exit /b
)

REM ===== OPTION 5: Local build + USB install =====
if "!opt!"=="5" (
    echo.
    echo Building locally...
    call flutter pub get
    if !errorlevel! neq 0 ( echo pub get failed! & pause & exit /b )
    call dart run build_runner build --delete-conflicting-outputs
    if !errorlevel! neq 0 ( echo build_runner failed! & pause & exit /b )
    call flutter build apk --release --obfuscate --split-debug-info=debug-info
    if !errorlevel! neq 0 ( echo APK build failed! & pause & exit /b )
    echo.
    echo Installing on phone via USB...
    call flutter install
    if !errorlevel! neq 0 ( echo Install failed! Check USB connection. & pause & exit /b )
    echo.
    echo =============================================================================
    echo     BUILD + INSTALL SUCCESSFUL!
    echo =============================================================================
    pause
    exit /b
)

echo Invalid choice.
endlocal
pause
goto :eof

REM ===== Helper: commit & push =====
:_commit_and_push
    git add -A
    git commit -m "%~1"
    if !errorlevel! neq 0 ( echo Nothing to commit. & pause & exit /b )
    git push
    echo.
    echo =============================================================================
    echo     PUSHED TO GITHUB!
    echo =============================================================================
    echo.
    echo GitHub Actions will build APK (~10 min).
    echo Download: https://github.com/krsnaSuraj/BillMed/releases/latest
    echo.
    echo For faster testing: run this script again and choose option 5
    echo to build locally and install on phone via USB.
    pause
