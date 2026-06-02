@echo off
title Tally Purchase Sync
cd /d "%~dp0"
echo ===================================================
echo TALLY PURCHASE SYNC STARTED
echo ===================================================
echo.
echo Running purchase synchronization...
python DO_NOT_EDIT_OR_DELETE_FOR_DEVELOPER_ONLY\purchase_sync.py
if %errorlevel% neq 0 (
    echo.
    echo Sync stopped with an error (Exit Code: %errorlevel%).
) else (
    echo.
    echo Purchase sync completed successfully.
)
echo.
pause
