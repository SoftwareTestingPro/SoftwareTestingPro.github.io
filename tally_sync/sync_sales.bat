@echo off
title Tally Sales Sync
cd /d "%~dp0"
echo ===================================================
echo TALLY SALES SYNC STARTED
echo ===================================================
echo.
echo Running daily sales Journal aggregation sync...
python DO_NOT_EDIT_OR_DELETE_FOR_DEVELOPER_ONLY\sales_sync.py
if %errorlevel% neq 0 (
    echo.
    echo Sync stopped with an error (Exit Code: %errorlevel%).
) else (
    echo.
    echo Sales sync completed successfully.
)
echo.
pause
