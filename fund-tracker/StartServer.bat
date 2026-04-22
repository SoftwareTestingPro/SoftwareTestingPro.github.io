@echo off
setlocal

:: Ensure we are in the project root
pushd "%~dp0"

echo ==========================================
echo    SoftwareTestingPro - Server Debug
echo ==========================================

set PORT=8000
set TARGET=fund-tracker/index.html

echo.
echo [1] Checking for Python...

:: Check for standard 'python'
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set PY_CMD=python
    goto :start_server
)

:: Check for 'py' (Python Launcher)
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set PY_CMD=py
    goto :start_server
)

echo [ERROR] No Python installation found! 
echo Please install Python from https://python.org
echo.
pause
exit

:start_server
echo [2] Using %PY_CMD% to start server...
echo [3] Opening: http://localhost:%PORT%/%TARGET%
echo.
echo ------------------------------------------
echo KEEP THIS WINDOW OPEN WHILE DEVELOPING
echo ------------------------------------------
echo.

:: Open the browser immediately
start "" "http://localhost:%PORT%/%TARGET%"

:: Start the server
%PY_CMD% -m http.server %PORT%

:: If the server stops or fails, this part runs:
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [CRITICAL ERROR] The server failed to start.
    echo Common reasons:
    echo 1. Port %PORT% is already being used by another app.
    echo 2. Python is installed but "http.server" module is missing.
    echo.
    echo See above for specific error details.
)

pause
popd
