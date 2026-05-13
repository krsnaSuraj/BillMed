@echo off
title BillMed - Build & Update
cd /d "%~dp0"

echo ================================================
echo       BillMed - Build & Update
echo    Commit + Push + Build APK in one step
echo ================================================
echo.

git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Git not found! Install from: https://git-scm.com/downloads
    pause
    exit /b
)

flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Flutter not found! Install from: https://docs.flutter.dev/get-started/install
    pause
    exit /b
)

git add -A

git diff --cached --quiet
if %errorlevel% equ 0 (
    echo No changes to commit. Skipping commit.
    goto :push
)

echo Changes detected:
git diff --cached --stat
echo.
git commit -m "Update %DATE% %TIME%"
if %errorlevel% neq 0 (
    echo Commit failed!
    pause
    exit /b
)
echo Committed successfully!

:push
echo.
echo Pushing to GitHub...
git push
if %errorlevel% neq 0 (
    echo Push failed! Check your internet connection.
    pause
    exit /b
)
echo Pushed to GitHub!

echo.
echo === Building APK ===
echo.

echo 1/4: Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo flutter pub get failed!
    pause
    exit /b
)

echo 2/4: Generating database code...
call dart run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo build_runner failed!
    pause
    exit /b
)

echo 3/4: Building release APK...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo APK build failed!
    pause
    exit /b
)

echo.
echo ================================================
echo         BUILD SUCCESSFUL!
echo ================================================
echo.
echo Send this file to phone:
echo %~dp0build\app\outputs\flutter-apk\app-release.apk
echo.
echo On phone: Tap APK -^> Install -^> Done
echo   (Enable "Install from unknown sources" if asked)
echo.
echo GitHub: https://github.com/krsnaSuraj/BillMed
echo.
pause
