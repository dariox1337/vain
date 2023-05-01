#!/bin/bash

source venv/bin/activate
python ./pyscripts/websocket_server.py &   # Start the Python server in the background
server_pid=$!                              # Store its process ID

# Define a function to kill the Python server when the script exits
cleanup() {
  echo "Killing Python websocket server with PID $server_pid"
  kill "$server_pid"
}

trap cleanup EXIT    # Set up the trap to call 'cleanup' on exit
./Godot_v4*.x86_64    # Run Godot

