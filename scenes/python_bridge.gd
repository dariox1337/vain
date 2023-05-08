extends Node

signal result_ready

var socket = WebSocketPeer.new()
var auth_key = "c2VjcmV0IGtleQ"
var auth = false
var results := {}


func _ready() -> void:
	socket.connect_to_url("ws://127.0.0.1:8080")
	await get_tree().create_timer(5.0).timeout
	# If there is no authentication in 5 seconds, something is wrong
	if not auth:
		Logger.logg("Could not connect to the python bridge in 5 seconds.", Logger.ERROR)
		var warning := AcceptDialog.new()
		warning.dialog_text = "Could not connect to the python bridge.
Some functionality will not work.
Try restarting the game."
		add_child(warning)
		warning.popup_centered()
		warning.show()
		set_process(false)


func _process(_delta) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not auth:
				socket.send_text(auth_key)
				Logger.logg("Python bridge connected.", Logger.INFO)
				auth = true
			while socket.get_available_packet_count():
				var reply = socket.get_packet().get_string_from_utf8()
				var id = reply.substr(0, 6) # first 6 digits is the id
				var result = reply.substr(7) # chars 7+ are the actual result
				results[id] = result
				result_ready.emit()
		WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		WebSocketPeer.STATE_CLOSED:
			if auth:
				var warning := AcceptDialog.new()
				warning.dialog_text = "The python bridge died.
Some functionality will not work anymore.
Save and restart the game."
				add_child(warning)
				warning.popup_centered()
				warning.show()
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				Logger.logg("WebSocket closed with code: %d, reason %s. Clean: %s" %\
							[code, reason, code != -1], Logger.ERROR)
				set_process(false) # Stop processing.

## This function sends a message with unique id over websocket to Python
## and return back the result
func eval(python_code : String) -> String:
	var id = str(randi_range(100000,999999)) # use 6 digit id
	# wait until connected
	while not auth:
		await get_tree().process_frame
	socket.send_text(id + "|" + python_code)
	# return result as a coroutine
	return await _fetch_result(id)

## This funtion actually fetches the result when it's available, 
## then erases it from the dictionary, and sends back to the original caller of
## PythonBridge.eval()
func _fetch_result(id: String) -> String:
	while not results.has(id):
		await self.result_ready
	var res : String = results[id]
	results.erase(id)
	return res
