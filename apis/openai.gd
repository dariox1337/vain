class_name OpenAIConfig extends APIConfig

var _http_request : HTTPRequest
var _httpsse_client : HTTPSSEClient
var current_message_uid : String
var openai_name_regex : RegEx


func _init() -> void:
	name = "OpenAI"
	config_scene = "res://apis/openai_config.tscn"
	presets = {"Default": OpenAIConfigPreset.new()}
	openai_name_regex = RegEx.create_from_string("[^a-zA-Z0-9_]")
	super._init()


func adopt_children() -> Array[Node]:
	_http_request = HTTPRequest.new()
	_http_request.name = "OpenAI_HTTPRequest"
	_http_request.request_completed.connect(_on_http_request_completed)
	_httpsse_client = HTTPSSEClient.new()
	_httpsse_client.name = "OpenAI_HTTPSSEClient"
	_httpsse_client.new_sse_event.connect(_on_sse_event)
	return [_http_request, _httpsse_client]


func new_preset(key : String) -> OpenAIConfigPreset:
	if presets.has(key):
		return presets[key]
	var new_p = OpenAIConfigPreset.new()
	presets[key] = new_p
	return new_p


func get_preset_properties() -> Array[String]:
	var global = super.get_preset_properties()
	var local = ["oai_key", "url", "model", "context_length", "response_length",
				"temperature", "frequency_penalty", "presence_penalty", 
				"keep_examples", "positional_prompts"]
	local.append(global)
	return local


func connect_to_api(preset: String) -> void:
	var headers := PackedStringArray(["Authorization: Bearer " + presets[preset].oai_key])
	var error := _http_request.request(
		presets[preset].url.path_join("models"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		Logger.logg("An error occurred in the HTTP request.", Logger.ERROR)


func _on_api_connected(_result, response_code, headers, body) -> void:
	if response_code >= 400:
		Logger.logg("Server replied with response code " + response_code, Logger.ERROR)
		Logger.logg("Headers: " + headers, Logger.ERROR)
		return
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	Logger.logg(JSON.stringify(response, "   "), Logger.DEBUG)
	Logger.logg("Available models:", Logger.INFO)
	for d in response["data"]:
		Logger.logg(d["id"], Logger.INFO)


func stop_generation() -> void:
	_http_request.cancel_request()
	_httpsse_client.cancel_request()

func gen_message(chat: ChatTreeNode, me: ChatParticipant, tree: ChatTree,
				preset_key: String, msg_uid: String) -> APIResult:
	var preset: OpenAIConfigPreset = presets[preset_key]
	var pos_prompts: Dictionary = preset.positional_prompts
	var data := {}
	var tokens := 3 # every reply is primed with three tokens
	var example_message_tokens := 0

	var starting_prompt_keys : Array = pos_prompts.keys()
	starting_prompt_keys = starting_prompt_keys.filter(func(number): return number > 0)
	starting_prompt_keys.sort()
	starting_prompt_keys.reverse()
	# count starting prompt tokens
	for pos in starting_prompt_keys:
		var prompt := create_positional_prompt(pos_prompts[pos], me, tree)
		if prompt != []:
			if pos_prompts[pos][0] == "examples":
				example_message_tokens += await get_number_of_tokens(prompt, preset.model)
			else:
				tokens += await get_number_of_tokens(prompt, preset.model)

	data["model"] = preset.model
	var messages : Array[Dictionary] = []
	var counter := -1
	# build chat log
	while true:
		# Inject ending prompts
		if pos_prompts.has(counter):
			var prompt = create_positional_prompt(pos_prompts[counter], me, tree)
			if prompt != []:
				messages.append_array(prompt)
				tokens += await get_number_of_tokens(prompt, preset.model)
		counter -= 1

		var message := {}
		if chat.get("participant"):
			if chat.participant.uid == me.uid:
				message["role"] = "assistant"
			else:
				message["role"] = "user"
		else:	# Treat removed participants as AI.
			message["role"] = "assistant"
		message["name"] = convert_name(chat.name)
		message["content"] = chat.message
		tokens += await get_number_of_tokens([message], preset.model)
		Logger.logg("Number of tokens: %s" % tokens, Logger.DEBUG)

		if preset.keep_examples: # When keeping examples, always count them in
			if tokens + example_message_tokens > preset.context_length - preset.response_length:
				break
		else: # otherwise don't count them because examples will be dropped when context is full
			if tokens > preset.context_length - preset.response_length:
				break

		messages.append(message)
		chat = chat.get_parent()
		if not chat:
			break

	# inject starting prompts
	for pos in starting_prompt_keys:
		var prompt := create_positional_prompt(pos_prompts[pos], me, tree)
		if prompt != []:
			if pos_prompts[pos][1] == "examples" and\
					(preset.keep_examples or\
					(tokens + example_message_tokens) < 
					(preset.context_length - preset.response_length)):
				messages.append_array(prompt)
			else:
				messages.append_array(prompt)

	# reverse the array because the messages were added in reverse order
	messages.reverse()
	
	data["messages"] = messages
	data["max_tokens"] = preset.response_length
	data["temperature"] = preset.temperature
	data["frequency_penalty"] = preset.frequency_penalty
	data["presence_penalty"] = preset.presence_penalty
	data["stream"] = preset.stream

	var json_data = JSON.stringify(data, "  ")
	Logger.logg(json_data, Logger.INFO)
	json_data = JSON.stringify(data)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + preset.oai_key])
	var url = preset.url.path_join("chat/completions")
	Logger.logg("Sending request to: %s" % url, Logger.INFO)

	current_message_uid = msg_uid
	if preset.stream:
		var error := _httpsse_client.get_events_from(url, headers, json_data)
		if error != OK:
			return APIResult.new(APIResult.ERROR, msg_uid, "Could not initiate streaming.")
	else:
		var error := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_data)
		if error != OK:
			return APIResult.new(APIResult.ERROR, msg_uid, "Could not send a HTTP request.")
	
	return APIResult.new(APIResult.STREAM, msg_uid, "")


func _on_http_request_completed(result, response_code, _headers, body) -> void:
	if result != OK:
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
	if response_code > 400:
		status = APIResult.ERROR
		if response:
			if typeof(response) == TYPE_DICTIONARY and response.has("error"):
				message = str(response_code) + " " + str(response["error"])
			else:
				message = str(response_code) + " " + str(response)
		else:
			message = str(response_code)
	elif response.has("error"):
		status = APIResult.ERROR
		message = response["error"]
	else:
		status = APIResult.STREAM_ENDED
		message = response["choices"][0]["message"]["content"]
	streaming_event.emit(APIResult.new(status, current_message_uid, str(message)))


func _on_sse_event(event) -> void:
	if event['event'] == "ERROR":
		var res := APIResult.new(APIResult.ERROR, current_message_uid, event['data'])
		_httpsse_client.close_open_connection()
		streaming_event.emit(res)
		return

	if event['data'] == '[DONE]\n':
		var res := APIResult.new(APIResult.STREAM_ENDED, current_message_uid, "")
		_httpsse_client.close_open_connection()
		streaming_event.emit(res)
		return

	var json := JSON.new()
	var err := json.parse(event['data'])
	if err != OK:
		Logger.logg("JSON Parse Error: %s in %s at line %s" %\
					[json.get_error_message(), event['data'], json.get_error_line()],
					Logger.ERROR)
	var parsed = json.data
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("choices"):
		parsed = parsed['choices'][0]['delta']
		if parsed.has("content"):
			var res := APIResult.new(APIResult.STREAM, current_message_uid, parsed["content"])
			streaming_event.emit(res)
	else:
		Logger.logg("Unknown message %s" % parsed, Logger.WARN)


func get_number_of_tokens(messages: Array[Dictionary], model: String) -> int:
	var tokens = 0
	for message in messages:
		var res = await PythonBridge.eval('closedai.num_tokens_in_single_message(%s, "%s")'\
											% [message, model])
		tokens += int(res)
	return int(tokens)


func create_positional_prompt(prompt: Array, me: ChatParticipant,
								tree: ChatTree) -> Array[Dictionary]:
	if prompt[1] == "examples":
			return parse_examples(me.chara.example_messages,
											tree.get_user_substitution(),
											me.chara.name)
	elif prompt[1] != "inactive" and prompt[2] != "":
		var text: String = prompt[2]
		text = tree.substitute(me, text)
		return [{"role" : prompt[1], "content" : text}]
	return []


func parse_examples(examples: String, user_name: String, chara_name: String) -> Array:
	var res := super.parse_examples(examples, user_name, chara_name)
	var messages: Array[Dictionary] = []
	var new_chat = {"role" : "system", "content" : "[Start a new chat]"}
	for msg in res:
		match msg[0]:
			"<START>":
				messages.append(new_chat)
			user_name:
				messages.append({"role" : "user",
								"content" : msg[1],
								"name" : convert_name(user_name)})
			chara_name:
				messages.append({"role" : "assistant",
								"content" : msg[1],
								"name" : convert_name(chara_name)})
	messages.reverse()
	return messages


func convert_name(chara_name: String) -> String:
	# The name field can contain only a-z, A-Z, 0-9, and underscores.
	var filtered_name := openai_name_regex.sub(chara_name, "_", true)
	return filtered_name.left(64)

