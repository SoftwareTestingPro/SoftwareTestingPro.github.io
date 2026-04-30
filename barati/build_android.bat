@echo off
echo ========================================
echo   Barati Android App Build
echo ========================================

:: 1. Sync dependencies
echo [1/2] Syncing dependencies...
cd source
call flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo ERROR: 'flutter pub get' failed.
    cd ..
    pause
    exit /b %errorlevel%
)

:: 2. Build the Android APK
echo [2/2] Building Android APK (Release)...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Android build failed.
    cd ..
    pause
    exit /b %errorlevel%
)

cd ..

echo.
echo ========================================
echo   SUCCESS!
echo.
echo   The Android APK is ready at:
echo   /barati/source/build/app/outputs/flutter-apk/app-release.apk
echo.
echo   Note: If you are ready for Play Store, 
echo   remember to sign your app and use 'bundle' 
echo   instead of 'apk'.
echo ========================================
pause
