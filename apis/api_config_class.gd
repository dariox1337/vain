class_name APIConfig extends Resource

signal api_connected()

@export var name : String = "Kobold"
@export var config_scene : String = "res://apis/kobold_config.tscn"
@export var presets: Dictionary = {"Default": null}
@export var last_used_preset : String = "Default"
var example_chats_regex : RegEx
var example_messages_regex : RegEx


func _init():
	# A pattern that captures everything between <START> tags as a single group
	example_chats_regex = RegEx.create_from_string('(?ms)(<START>|\\A)(.+?)(?=<START>|\\z)')
	# A pattern that captures {{char}} and {{user}} at the beginning of lines,
	# and the following text in separate groups.
	example_messages_regex = RegEx.create_from_string(
		'(?ms)^\\s*({{\\w+}})\\s*:*\\s*(.+?)(?=\\n\\s*{{|\\z)')

## If the api needs nodes (e.g. HTTPRequest), send them in an array of nodes.
## The main game scene will add the nodes to the scene
func adopt_children() -> Array[Node]:
	return []

## This func must return a new preset specific to the api
func new_preset(_key: String):
	pass

## This func must copy "old preset" settings to "new preset"
func copy_preset(old_key: String, new_key: String) -> void:
	if not presets.has(old_key) or not presets.has(new_key):
		Logger.logg("Couldn't find old or new preset for copying.", Logger.ERROR)
		return
	var properties := get_preset_properties()
	for prop in properties:
		var old_prop = presets[old_key].get(prop)
		presets[new_key].set(prop, old_prop)


## Return an array of properties specific to the api because
## Godot's get_property_list() returns many Godot-class-specific properties,
## which we don't care about
func get_preset_properties() -> Array[String]:
	return []


## Unused for now
func connect_to_api(_preset: String) -> void:
	pass


## This function generates response by traversing the chat tree up from the given node
## until either reaching the root or max_context.
## _parent is the parent node
## _part is the participant who should wrtie the response.
## _tree is the whole tree where API can find chat settings and tree.substitute() (check it)
## _preset is the api-specific configuration preset
func gen_message(_parent: ChatTreeNode, _part: ChatParticipant, _tree: ChatTree,
				_preset: String) -> APIResult:
	return APIResult.done(APIResult.OK, "")


func parse_examples(examples: String, user_name: String, chara_name: String) -> Array:
	var res := []
	var chats := example_chats_regex.search_all(examples)
	for chat in chats:
		res.append(["<START>"])
		var messages := example_messages_regex.search_all(chat.strings[2])
		for message in messages:
			var chara_sub = message.strings[1].replacen("{{user}}", user_name)
			chara_sub = chara_sub.replacen("{{char}}", chara_name)
			var message_sub = message.strings[2].replacen("{{user}}", user_name)
			message_sub = message_sub.replacen("{{char}}", user_name)
			res.append([chara_sub, message_sub])
	# add closing <START> to indicate new chat
	if res.size() > 0 and res[-1][0] != "<START>":
		res.append(["<START>"])
	return res

func http_request_error_message(result: int) -> String:
	match result:
		HTTPRequest.Result.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "HTTP chunked body size mismatch."
		HTTPRequest.Result.RESULT_CANT_CONNECT:
			return "HTTP request failed while connecting."
		HTTPRequest.Result.RESULT_CANT_RESOLVE:
			return "HTTP request failed while resolving."
		HTTPRequest.Result.RESULT_CONNECTION_ERROR:
			return "HTTP request failed due to connection (read/write) error."
		HTTPRequest.Result.RESULT_TLS_HANDSHAKE_ERROR:
			return "HTTP request failed on TLS handshake."
		HTTPRequest.Result.RESULT_NO_RESPONSE:
			return "HTTP request does not have a response (yet)."
		HTTPRequest.Result.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "HTTP request exceeded its maximum size limit, see body_size_limit."
		HTTPRequest.Result.RESULT_BODY_DECOMPRESS_FAILED:
			return "HTTP body decompress failed."
		HTTPRequest.Result.RESULT_REQUEST_FAILED:
			return "HTTP request failed (currently unused)."
		HTTPRequest.Result.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "HTTP request couldn't open the download file."
		HTTPRequest.Result.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "HTTP request couldn't write to the download file."
		HTTPRequest.Result.RESULT_REDIRECT_LIMIT_REACHED:
			return "HTTP request reached its maximum redirect limit, see max_redirects."
		HTTPRequest.Result.RESULT_TIMEOUT:
			return "HTTP request timeout."
	return "Unknown error %s" % result

