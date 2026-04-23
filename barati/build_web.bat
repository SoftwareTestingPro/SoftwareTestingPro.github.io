@echo off
echo ========================================
echo   Barati Self-Contained Web Build
echo ========================================

:: 1. Build the Flutter Web project
echo [1/2] Building Flutter Web...
call flutter build web --base-href "/barati/app/" --release

:: 2. Deploy build output to the /app folder
:: This keeps the root directory clean for source code
echo [2/2] Deploying build to /app folder...
if not exist "app" mkdir "app"
xcopy /s /e /y "build\web\*" "app\"

echo.
echo ========================================
echo   SUCCESS!
echo.
echo   The web build has been deployed directly 
echo   inside your 'barati' folder.
echo.
echo   You can now commit and push the contents 
echo   of this folder to GitHub.
echo ========================================
pause
