@echo off
echo Syncing dependencies...
call flutter pub get
echo Starting Barati Web Server...
cd /d %~dp0
flutter run -d chrome
pause
