class_name UserConfig extends APIConfig

signal message_received
var message: String
var last_msg_uid: String


func _init() -> void:
	name = "User"
	config_scene = "res://apis/user_config.tscn"
	presets = {"Default": UserConfigPreset.new()}
	UserMessageBus.new_user_message.connect(_on_new_message)


func new_preset(key : String) -> UserConfigPreset:
	if presets.has(key):
		return presets[key]
	var new_p = UserConfigPreset.new()
	presets[key] = new_p
	return new_p


func gen_message(_chat: ChatTreeNode, _part: ChatParticipant, _tree: ChatTree,
				_preset: String, msg_uid: String) -> APIResult:
	message = ""
	last_msg_uid = msg_uid
	return APIResult.new(APIResult.STREAM, msg_uid, message)


func _on_new_message(new_message: String) -> void:
	message = new_message
	var res = APIResult.new(APIResult.STREAM_ENDED, last_msg_uid, message)
	streaming_event.emit(res)
