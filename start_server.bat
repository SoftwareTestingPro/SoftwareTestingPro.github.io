@echo off
echo Starting local HTTP server...
:: Start the server in a new minimized window so it doesn't clutter the current one
start /min "Website Server" python server.py

echo Waiting for server to initialize...
timeout /t 2 /nobreak > nul

echo Launching Chrome...
start chrome "http://localhost:8000"

echo Server is running at http://localhost:8000
echo Close the "Website Server" window to stop the server.
