class_name ChatParticipant extends Resource

signal api_changed
signal wait_state_entered(truefalse)

@export var uid : String:
	set(new):
		uid = new
		chara = Utils.get_chara_by_uid(uid)
# do not export to see new changes when character is updated
var chara : Character = null
# api key in APIs.list dictionary
@export var api : String:
	set(new_value):
		api = new_value
		api_changed.emit()
# preset key in APIConfig.presets dictionary
@export var preset : String

var substitutions = {}
var apis = load("user://apis.tres")

func gen_message(parent: ChatTreeNode, tree: ChatTree, callback: Callable) -> void:
	Logger.logg("Waiting for message from %s" % chara.name, Logger.DEBUG)
	if api != "User":
		wait_state_entered.emit(true)
	var result : APIResult = await apis.list[api].gen_message(parent, self, tree, preset)
	if api != "User":
		wait_state_entered.emit(false)
	# Check if the chat still exists before calling the callback
	if callback.get_object():
		callback.call(self, result, parent)

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
