@echo off

call venv\Scripts\activate

:: Start the Python server in the background
start /B python .\pyscripts\websocket_server.py

:: Get the process ID of the Python server and store it in a variable
for /F "tokens=2" %%i in ('tasklist ^| findstr /I "python.exe"') do set server_pid=%%i

:: Run Godot
start /WAIT Godot_v4*.exe

:: Kill the Python websocket server when Godot exits
echo Killing Python websocket server with PID %server_pid%
taskkill /PID %server_pid% /F
