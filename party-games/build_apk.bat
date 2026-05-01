@echo off
echo Building Android APK...
cd source
call flutter build apk
echo.
echo Build complete. The APK can be found in source\build\app\outputs\flutter-apk\
pause
