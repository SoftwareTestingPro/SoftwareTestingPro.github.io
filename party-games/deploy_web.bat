@echo off
echo ========================================
echo   Building Party Games for Web Deployment
echo ========================================
echo.

cd app
echo Building Flutter Web...
call flutter build web --base-href "/party-games/" --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Flutter build failed.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Cleaning root directory for deployment...
cd ..
:: We keep the app folder and batch files, remove everything else that came from the build
:: This ensures the root contains the LATEST built version of the web app.

echo Copying build files to root...
xcopy /E /I /Y "app\build\web\*" ".\"

echo.
echo ========================================
echo   DEPLOYMENT READY!
echo ========================================
echo 1. git add .
echo 2. git commit -m "Deploy latest Flutter web"
echo 3. git push origin main
echo.
echo Your app will be at: https://SoftwareTestingPro.github.io/party-games/
echo ========================================
pause
