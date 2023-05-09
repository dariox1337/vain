class_name ChatParticipant extends Resource

signal api_changed
signal streaming_message_event(api_result: APIResult)

@export var uid: String:
	set(new):
		uid = new
		chara = Utils.get_chara_by_uid(uid)
# do not export to see new changes when character is updated
var chara: Character = null
# api key in APIs.list dictionary
@export var api : String:
	set(new_value):
		api = new_value
		apis.list[api].streaming_event.connect(_on_streaming_event)
		api_changed.emit()
# preset key in APIConfig.presets dictionary
@export var preset: String

var substitutions = {}
var apis = load("user://apis.tres")
var last_msg_uid: String


func gen_message(parent: ChatTreeNode, tree: ChatTree, callback: Callable) -> void:
	Logger.logg("Waiting for message from %s" % chara.name, Logger.DEBUG)
	last_msg_uid = Utils.gen_new_uid()
	var result : APIResult = await apis.list[api].gen_message(parent, self, tree, 
																preset, last_msg_uid)
	# Check if the chat still exists before calling the callback
	if callback.get_object():
		callback.call(self, result, parent)


func _on_streaming_event(api_result: APIResult) -> void:
	if api_result.msg_uid != last_msg_uid:
		# This is a message for a different participant
		return
	streaming_message_event.emit(api_result, self)


func stop_generation() -> void:
	apis.list[api].stop_generation()


func to_dict() -> Dictionary:
	var dict = {
		"uid" : uid,
		"api" : api,
		"preset" : preset,
	}
	return dict


static func from_dict(dict: Dictionary) -> ChatParticipant:
	var loaded := ChatParticipant.new()
	loaded.uid = dict["uid"]
	loaded.api = dict["api"]
	loaded.preset = dict["preset"]
	return loaded
