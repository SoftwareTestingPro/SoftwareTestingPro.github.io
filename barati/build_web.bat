@echo off
echo ========================================
echo   Barati Root Web Build
echo ========================================

:: 1. Sync dependencies
echo [1/4] Syncing dependencies in /source...
cd source
call flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo ERROR: 'flutter pub get' failed.
    cd ..
    pause
    exit /b %errorlevel%
)

:: 2. Build the Flutter Web project
echo [2/4] Building Flutter Web...
call flutter build web --base-href "/barati/" --release
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Flutter build failed.
    cd ..
    pause
    exit /b %errorlevel%
)

:: 3. Deploy build output to the root folder
echo [3/4] Deploying build to root folder...
xcopy /s /e /y "build\web\*" "..\"

:: 4. Clean up the build folder to save space (prevents duplication)
echo [4/4] Cleaning up intermediate build files...
if exist "build" rd /s /q "build"

cd ..

echo.
echo ========================================
echo   SUCCESS!
echo.
echo   Project size has been optimized by 
echo   removing the duplicate build folder.
echo.
echo   1. Commit and push all files in /barati.
echo   2. Visit: https://softwaretestingpro.github.io/barati/
echo ========================================
pause
