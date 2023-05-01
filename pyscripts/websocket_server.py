import asyncio
import json
import websockets
import core
import closedai

auth_key = "c2VjcmV0IGtleQ"

async def websocket_handler(websocket, path):
    if auth_key != await websocket.recv():
        print(f"Client {websocket.remote_address} provided wrong auth key")
        return
    print(f"Client connected: {websocket.remote_address}")

    try:
        while True:
            # TODO: Implement concurrent processing of requests
            # or open multiple sockets in Godot and use free ones
            data = await websocket.recv()
            data = data.strip()
            uid = data[:6]
            func_call = data[7:]
            print(f"Call {uid} to evaluate {func_call}")

            # Use eval() to evaluate the received expression
            result = eval(func_call)

            # Send the result back as a string
            await websocket.send(uid + "|" + str(result))

    except websockets.ConnectionClosed:
        print(f"Client disconnected: {websocket.remote_address}")

start_server = websockets.serve(websocket_handler, "127.0.0.1", 8080)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
