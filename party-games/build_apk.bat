@echo off
echo Building Android APK...
cd app
call flutter build apk
echo.
echo Build complete. The APK can be found in app\build\app\outputs\flutter-apk\
pause
