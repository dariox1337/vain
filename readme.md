# vAIn
## A vain attempt to merge visual novels and artificial intelligence.
This is a game that allows you to interact with text generation AIs.
Being implemented in a game engine (Godot) provides an avenue to add 3D avatars in the future.
Developed and tested only on Linux, but Windows and Mac should be supported out of the box 
(not tested). Theoretically, mobile platforms should be supported too.
Contributors welcome! Godot script is easy.

## Features
* Tree-style chats that allow switching branches at any moment.
* Multi-participant chats. You can have an arbitrary number of participants in chat. 
Just make sure that the AI you use understands multiple participants.
* Multi-API. Every participant can use any supported api with any preset. For instance, 
you can have a chat between Kobold and GPT-3.5 and even without humans.

## Installation
1. Download this repo and install it wherever you want
2. Install Python if you don't have it
3. Create a new virtual environment inside the project folder:
   - On Windows: `python -m venv venv`
   - On Linux: `python3 -m venv venv`
3. Activate the virtual environment:
   - On Windows: `myenv\Scripts\activate`
   - On macOS and Linux: `source myenv/bin/activate`
5. Install the packages from requirements.txt: `pip install -r requirements.txt`
6. Download Godot 4 for your platform https://godotengine.org/download/
7. Copy the Godot executable into the project folder
8. Run the game
   - On Windows: run stat.bat, but keep in mind that it's not tested and the script will kill 
the first instance of python.exe it finds on exit.
   - On Linux: run start.sh which will launch Python and Godot.
   - Note for developers: you probably want to launch Python separately with 
`python ./pyscripts/websocket_server.py` so it remains open between test runs.
9. Import a character card (png or json) in "CHAT" settings, add a character to your chat,
and set their api.

## Supported APIs
* Kobold
* OpenAI
* User (You're just another API ¯\\\_(ツ)\_/¯)

## For developers
Launch Godot executable from any folder outside of the project folder,
then open the game project in the editor.

Every chat is an instance of a class named ChatTree `resources/chat_tree.gd` It holds references
to chat participants `resources/chat_participant.gd` and the first tree node 
`resources/chat_tree_node.gd`. Each node has references to its children and the parent node.
The main chat scene `scenes/chat/chat.gd` is a simple state machine that calls chat participants 
in turns and tells them to generate messages. Every participant has an api associated with it. 
The participant forwards the request to its api. User input is mostly handled as another api, 
aside from small exceptions.

The game starts with `scenes/start.tscn`, then moves on to `scenes/game_scene/game_scene.tscn`

Since AI-field is dominated by Python, there is a bridge that allows to call Python scripts 
from within the game.

## License
AGPL-3

## Credits
* Godot Engine https://godotengine.org/ (MIT license)
* Thanks to TavernAI and SillyLoss mod for inspiration and background pics (Unknown license)
* Icon theme by Font Awesome https://fontawesome.com (Icons: CC BY 4.0)
