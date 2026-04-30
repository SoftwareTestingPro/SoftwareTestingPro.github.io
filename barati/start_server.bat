@echo off
echo Starting Barati Web Server...
cd /d %~dp0\source
echo Syncing dependencies...
call flutter pub get
flutter run -d chrome
pause
