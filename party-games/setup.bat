@echo off
echo Running Flutter Clean and Pub Get...
cd app
call flutter clean
call flutter pub get
echo.
echo Setup complete.
pause
