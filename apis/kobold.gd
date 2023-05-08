class_name KoboldConfig extends APIConfig


signal config_set
var _config_http_request : HTTPRequest
var config_result := false

signal result_ready
var _prompt_http_request : HTTPRequest
var final_result := {
	"status" : OK,
	"message" : "",
}

var next_message_regex: RegEx

func _init() -> void:
	name = "Kobold"
	config_scene = "res://apis/kobold_config.tscn"
	presets = {"Default": KoboldConfigPreset.new()}
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
	var local = ["url", "max_context_length", "max_length", "rep_pen",
			"rep_pen_range", "rep_pen_slope", "temperature", "tfs",
			"top_a", "top_k", "top_p", "multigeneration", "keep_examples",
			"single_line", "use_story", "use_world_info", "sampler_order",
			"kobold_memory", "authors_note"]
	local.append_array(global)
	return local


func gen_message(chat: ChatTreeNode, me: ChatParticipant, tree: ChatTree,
				preset_key := "Default") -> APIResult:
	var preset : KoboldConfigPreset = presets[preset_key]
	var full_message := ""
	while true:
		_gen_message(chat, full_message, me, tree, preset)
		await result_ready
		if final_result["status"] == APIResult.OK:
			var msg = next_message_regex.search(final_result["message"])
			if msg:
				final_result["message"] = msg.strings[0]
				break
			elif preset.multigeneration:
				Logger.logg("Continuing generation.", Logger.INFO)
				full_message += final_result["message"]
			else: break
		else: break
	if full_message != "":
		final_result["status"] = APIResult.OK
		final_result["message"] = full_message + final_result["message"]
	return APIResult.new(final_result["status"], final_result["message"])


func _gen_message(chat: ChatTreeNode, full_message: String, me: ChatParticipant,
					tree: ChatTree,	preset: KoboldConfigPreset) -> void:
	var data := {}

	var messages: Array = []
	# If we're doing multi-generation, there might be previous parts here, append them.
	messages.append(full_message)
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
	if preset.kobold_memory != "":
		var mem = tree.substitute(me, preset.kobold_memory)
		set_config({"value" : mem}, "v1/config/memory", preset)
		await config_set
		if config_result == true:
			data["use_memory"] = true
	
	# Compile author's note
	data["use_authors_note"] = false
	if preset.authors_note != "":
		var note = tree.substitute(me, preset.authors_note)
		set_config({"value" : note}, "v1/config/authors_note", preset)
		await config_set
		if config_result == true:
			data["use_authors_note"] = true

	# Compile other options
	data["max_context_length"] = preset.max_context_length - preset.max_length
	data["max_length"] = preset.max_length
	data["rep_pen"] = preset.rep_pen
	data["rep_pen_range"] = preset.rep_pen_range
	data["rep_pen_slope"] = preset.rep_pen_slope
	data["temperature"] = preset.temperature
	data["tfs"] = preset.tfs
	data["top_a"] = preset.top_a
	data["top_k"] = preset.top_k
	data["top_p"] = preset.top_p
	data["use_story"] = preset.use_story
	data["use_world_info"] = preset.use_world_info
	data["sampler_order"] = preset.sampler_order

	var json_data = JSON.stringify(data, "  ")
	Logger.logg(json_data, Logger.INFO)
	json_data = JSON.stringify(data)

	var headers := PackedStringArray(["Content-Type: application/json"])
	var url = preset.url.path_join("v1/generate")
	Logger.logg("Sending request to: %s" % url, Logger.INFO)
	_prompt_http_request.cancel_request()
	var error := _prompt_http_request.request(url,	headers, HTTPClient.METHOD_POST, json_data)
	if error != OK:
		Logger.logg("An error occurred in the HTTP request.", Logger.ERROR)
		final_result = {"status" : "Error", "message" : "An error occurred in the HTTP request."}
		result_ready.emit()


func _on_prompt_http_request_completed(result, response_code, _headers, body) -> void:
	if result != 0:
		var err = http_request_error_message(result)
		Logger.logg(err, Logger.ERROR)
		final_result = {"status" : APIResult.ERROR,
						"message" : err}
		result_ready.emit()
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
		status = OK
		message = response["results"][0]["text"]
		message = message.strip_edges() # strip \n, \t from the beginning and the end
	final_result = {"status" : status, "message" : str(message)}
	result_ready.emit()


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
