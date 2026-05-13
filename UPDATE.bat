@echo off
title BillMed - Build & Update
cd /d "%~dp0"

echo ================================================
echo       BillMed - Build & Update
echo    Bump version + Commit + Push + GitHub builds
echo ================================================
echo.

git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Git not found! Install from: https://git-scm.com/downloads
    pause
    exit /b
)

:: Check if version needs bumping
setlocal enabledelayedexpansion
for /f "tokens=2 delims=: " %%a in ('findstr "^version:" pubspec.yaml') do set FULL_VER=%%a
for /f "tokens=1 delims=+" %%a in ("!FULL_VER!") do set VER=%%a
for /f "tokens=2 delims=+" %%a in ("!FULL_VER!") do set BUILD=%%a
if "!BUILD!"=="" set BUILD=1
set /a NEW_BUILD=BUILD+1

echo Current version: !VER!+!BUILD!
echo New version:     !VER!+!NEW_BUILD!
echo.
echo Press Enter to bump version and push (Ctrl+C to cancel)
echo Or close now to skip version bump
pause >nul

:: Bump build number
powershell -Command "(Get-Content pubspec.yaml) -replace 'version: !FULL_VER!', 'version: !VER!+!NEW_BUILD!' | Set-Content pubspec.yaml"

git add -A

git diff --cached --quiet
if %errorlevel% equ 0 (
    echo No changes to commit.
) else (
    echo Changes detected:
    git diff --cached --stat
    echo.
    git commit -m "Update v!VER!+!NEW_BUILD!"
    if !errorlevel! neq 0 (
        echo Commit failed!
        pause
        exit /b
    )
    echo Committed!
)

echo.
echo Pushing to GitHub...
git push
if !errorlevel! neq 0 (
    echo Push failed!
    pause
    exit /b
)

echo.
echo ================================================
echo           PUSHED TO GITHUB!
echo ================================================
echo.
echo GitHub Actions will auto-build the APK (~10 min).
echo.
echo Papa ko ye link bhejo:
echo https://github.com/krsnaSuraj/BillMed/releases/latest
echo.
echo Waha jakar vo app-release.apk download karega
echo aur install karega.
echo.
echo OR local build karna hai to:
echo   flutter pub get
echo   dart run build_runner build --delete-conflicting-outputs
echo   flutter build apk --release
echo.
endlocal
pause
