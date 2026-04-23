@echo off
echo ========================================
echo   Barati Self-Contained Web Build
echo ========================================

:: 1. Sync dependencies
echo [1/3] Syncing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo ERROR: 'flutter pub get' failed.
    pause
    exit /b %errorlevel%
)

:: 2. Build the Flutter Web project
echo [2/3] Building Flutter Web...
call flutter build web --base-href "/barati/app/" --release
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Flutter build failed.
    pause
    exit /b %errorlevel%
)

:: 3. Deploy build output to the /app folder
echo [3/3] Deploying build to /app folder...

:: Clean existing app folder to ensure no stale files
if exist "app" rd /s /q "app"
mkdir "app"

xcopy /s /e /y "build\web\*" "app\"

echo.
echo ========================================
echo   SUCCESS!
echo.
echo   The latest version of Barati is now 
echo   ready in the '/app' folder.
echo.
echo   1. Commit and push the 'app' folder.
echo   2. Visit: https://softwaretestingpro.github.io/barati/app/
echo ========================================
pause
