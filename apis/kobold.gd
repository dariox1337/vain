class_name KoboldConfig extends APIConfig


signal config_set
var _config_http_request : HTTPRequest
var config_result := false
var _prompt_http_request : HTTPRequest

var next_message_regex: RegEx
var current_preset: KoboldConfigPreset
var current_message_uid: String
var data: Dictionary


func _init() -> void:
	name = "Kobold"
	config_scene = "res://apis/kobold_config.tscn"
	presets = {"Default": KoboldConfigPreset.new()}
	# Regex that looks for "name:" at the beginning of a line,
	# which indicates that a differen character statred talking
	next_message_regex = RegEx.create_from_string("(?ms)^(.+?)(?=\\n.+?:)")
	super._init()


func adopt_children() -> Array[Node]:
	_prompt_http_request = HTTPRequest.new()
	_prompt_http_request.name = "Kobold_HTTPRequest_prompt"
	_prompt_http_request.request_completed.connect(_on_prompt_http_request_completed)
	_config_http_request = HTTPRequest.new()
	_config_http_request.name = "Kobold_HTTPRequest_config"
	_config_http_request.request_completed.connect(_on_config_http_request_completed)
	return [_prompt_http_request, _config_http_request]


func new_preset(key : String) -> KoboldConfigPreset:
	if presets.has(key):
		return presets[key]
	var new_p = KoboldConfigPreset.new()
	presets[key] = new_p
	return new_p


func get_preset_properties() -> Array[String]:
	var global = super.get_preset_properties()
	var local: Array[String] = ["url", "max_context_length", "max_length", "rep_pen",
			"rep_pen_range", "rep_pen_slope", "temperature", "tfs",
			"top_a", "top_k", "top_p", "multigeneration", "keep_examples",
			"single_line", "use_story", "use_world_info", "sampler_order",
			"kobold_memory", "authors_note"]
	local.append_array(global)
	return local


func stop_generation() -> void:
	_config_http_request.cancel_request()
	_prompt_http_request.cancel_request()


func gen_message(chat: ChatTreeNode, me: ChatParticipant, tree: ChatTree,
				preset_key: String, msg_uid: String) -> APIResult:
	current_preset = presets[preset_key]
	current_message_uid = msg_uid
	data = {}

	var messages: Array = []
	# Add speaker name to make it clear for the model who should speak
	messages.append("%s: " % me.chara.name)
	# Compile message log
	while true:
		messages.append("%s: %s\n" % [chat.name, chat.message])
		chat = chat.get_parent()
		if not chat:
			break
	# Compile examples
	var examples = parse_examples(me.chara.example_messages, tree.get_user_substitution(),
									me.chara.name)
	for example in examples:
		messages.append(example)
	messages.reverse()
	var messages_string : String = "".join(messages)
	data["prompt"] = messages_string

	# Compile memory
	data["use_memory"] = false
	if current_preset.kobold_memory != "":
		var mem = tree.substitute(me, current_preset.kobold_memory)
		set_config({"value" : mem}, "v1/config/memory", current_preset)
		await config_set
		if config_result == true:
			data["use_memory"] = true
	
	# Compile author's note
	data["use_authors_note"] = false
	if current_preset.authors_note != "":
		var note = tree.substitute(me, current_preset.authors_note)
		set_config({"value" : note}, "v1/config/authors_note", current_preset)
		await config_set
		if config_result == true:
			data["use_authors_note"] = true

	# Compile other options
	data["max_context_length"] = current_preset.max_context_length - current_preset.max_length
	data["max_length"] = current_preset.max_length
	data["rep_pen"] = current_preset.rep_pen
	data["rep_pen_range"] = current_preset.rep_pen_range
	data["rep_pen_slope"] = current_preset.rep_pen_slope
	data["temperature"] = current_preset.temperature
	data["tfs"] = current_preset.tfs
	data["top_a"] = current_preset.top_a
	data["top_k"] = current_preset.top_k
	data["top_p"] = current_preset.top_p
	data["use_story"] = current_preset.use_story
	data["use_world_info"] = current_preset.use_world_info
	data["sampler_order"] = current_preset.sampler_order
	return _send_request()


func _send_request() -> APIResult:
	var json_data = JSON.stringify(data, "  ")
	Logger.logg(json_data, Logger.INFO)
	json_data = JSON.stringify(data)

	var headers := PackedStringArray(["Content-Type: application/json"])
	var url = current_preset.url.path_join("v1/generate")
	Logger.logg("Sending request to: %s" % url, Logger.INFO)
	if current_preset.stream:
		pass
	else:
		_prompt_http_request.cancel_request()
		var error := _prompt_http_request.request(url, headers, HTTPClient.METHOD_POST, json_data)
		if error != OK:
			return APIResult.new(APIResult.ERROR, current_message_uid, "HTTP request failed.")
	return APIResult.new(APIResult.STREAM, current_message_uid, "")


func _on_prompt_http_request_completed(result, response_code, _headers, body) -> void:
	if result != 0:
		var err = http_request_error_message(result)
		Logger.logg(err, Logger.ERROR)
		streaming_event.emit(APIResult.new(APIResult.ERROR, current_message_uid, str(err)))
		return
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	Logger.logg(JSON.stringify(response, "  "), Logger.INFO)
	var status
	var message
	if response.has("error"):
		status = APIResult.ERROR
		message = response["error"]
	elif response_code > 400:
		status = APIResult.ERROR
		message = response
	else:
		message = response["results"][0]["text"]
		var is_next_msg = next_message_regex.search(message)
		if is_next_msg:
			status = APIResult.STREAM_ENDED
			message = is_next_msg.strings[0]
		elif current_preset.multigeneration:
			status = APIResult.STREAM
			data["prompt"] += message
			_send_request()
		else:
			status = APIResult.STREAM_ENDED
	streaming_event.emit(APIResult.new(status, current_message_uid, str(message)))


func parse_examples(examples: String, user_name: String, chara_name: String) -> Array:
	var res := super.parse_examples(examples, user_name, chara_name)
	var messages: Array[String] = []
	for msg in res:
		match msg[0]:
			"<START>":
				messages.append("%s\n" % msg[0])
			user_name:
				messages.append("%s: %s\n" % [user_name, msg[1]])
			chara_name:
				messages.append("%s: %s\n" % [chara_name, msg[1]])
	messages.reverse()
	return messages


func set_config(conf: Dictionary, conf_address: String, preset: KoboldConfigPreset) -> void:
	var json = JSON.stringify(conf)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url = preset.url.path_join(conf_address)
	Logger.logg("Sending request to: %s" % url, Logger.INFO)
	_config_http_request.cancel_request()
	var error := _config_http_request.request(url, headers, HTTPClient.METHOD_PUT, json)
	if error != OK:
		Logger.logg("An error occurred in the HTTP request.", Logger.ERROR)
		config_result = false
		config_set.emit()


func _on_config_http_request_completed(result, response_code, _headers, body) -> void:
	if result != 0:
		var err = http_request_error_message(result)
		Logger.logg(err, Logger.ERROR)
		config_result = false
	if response_code == 200:
		config_result = true
	else:
		Logger.logg(body.get_string_from_utf8(), Logger.ERROR)
		config_result = false
	config_set.emit()
