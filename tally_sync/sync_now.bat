@echo off
title Tally Sync Service
cd /d "%~dp0"
echo ===================================================
echo TALLY SYNC STARTED
echo ===================================================
echo.
echo Starting sync service...
python DO_NOT_EDIT_OR_DELETE_FOR_DEVELOPER_ONLY\scheduler.py
if %errorlevel% neq 0 (
    echo.
    echo Sync stopped with an error (Exit Code: %errorlevel%).
) else (
    echo.
    echo Sync completed successfully.
)
echo.
pause
