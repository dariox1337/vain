class_name ChatTree extends Resource

signal participants_changed
signal scenario_changed

@export var name := ""
@export var uid : String
@export var root : ChatTreeNode = null
@export var participants : Array[ChatParticipant]
@export var scenario := "":
	set(new_scenario):
		scenario = new_scenario
		scenario_changed.emit()
@export var chat_substitutions := {}

func _init():
	uid = Utils.gen_new_uid()


func new_node(chara : ChatParticipant, message : String, parent : ChatTreeNode) -> ChatTreeNode:
	var new
	if not parent:
		root = ChatTreeNode.chat_new(self, chara, message, null)
		new = root
	else:
		new = ChatTreeNode.chat_new(self, chara, message, parent)
		parent._children.append(new)
	return new


func participant_joined(chara : Character, api := "User", preset := "Default") -> ChatParticipant:
	for existing_part in participants:
		if existing_part.uid == chara.uid:
			return null
	var part = ChatParticipant.new()
	part.uid = chara.uid
	part.api = api
	part.preset = preset
	participants.append(part)
	participants_changed.emit()
	return part


func participant_left(part: ChatParticipant) -> void:
	participants.erase(part)
	participants_changed.emit()


func get_participant_name(part_uid : String) -> String:
	for p in participants:
		if p.chara.uid == part_uid:
			return p.chara.name
	return "Character Name not Found"


## Remove participants whose character cards were deleted
func prune_deleted_participants() -> void:
	var to_erase := []
	for part in participants:
		if not Utils.get_chara_by_uid(part.uid):
			to_erase.append(part)
	for part in to_erase:
		participants.erase(part)
		save()


func substitute(for_part: ChatParticipant, text: String) -> String:
	# The order of substitutions matters, {{char}} and {{user} should be the last.
	text = text.replacen("{{scenario}}", scenario)
	text = text.replacen("{{description}}", for_part.chara.description)
	text = text.replacen("{{personality}}", for_part.chara.personality)
	text = text.replacen("{{char}}", for_part.chara.name)
	for pattern in chat_substitutions.keys():
		text = text.replacen(pattern, chat_substitutions[pattern])
	return text


func get_user_substitution() -> String:
	if chat_substitutions.has("{{user}}"):
		return chat_substitutions["{{user}}"]
	else:
		return "{{user}}"


func save() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://chats/"):
		var err = dir.make_dir("user://chats")
		if err != OK:
			Logger.logg("Code: %s. Could not create user://chats dir." % [err], Logger.ERROR)
			return

	var file_path := "user://chats/%s_%s.json" % [uid, name]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var root_dict: Dictionary
		if root:
			root_dict = root.to_dict()
		var parts: Array[Dictionary] = []
		for p in participants:
			parts.append(p.to_dict())
		var params := {
			"name" : name,
			"uid" : uid,
			"root" : root_dict,
			"participants" : parts,
			"scenario" : scenario,
			"chat_substitutions" : chat_substitutions,
		}
		file.store_string(JSON.stringify(params, "  "))


static func load_from_file(file_path: String) -> ChatTree:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var loaded := ChatTree.new()
		var params : Dictionary
		var json_str := file.get_as_text()
		var json := JSON.new()
		var error := json.parse(json_str)
		if error == OK:
			params = json.data
		else:
			Logger.logg("JSON Parse Error: %s in %s at line %s" %\
						[json.get_error_message(), json_str, json.get_error_line()],\
						Logger.ERROR)
		for prop in ["name", "uid", "scenario", "chat_substitutions"]:
			if params.has(prop):
				loaded.set(prop, params[prop])
			else:
				Logger.logg('Chat save file is missing "%s" field.' % prop, Logger.WARN)
		if params.has("participants"):
			for part in params["participants"]:
				loaded.participants.append(ChatParticipant.from_dict(part))
		else:
			Logger.logg('Chat save file is missing "participants" field.', Logger.WARN)
		if params.has("root") and params["root"]:
			loaded.root = ChatTreeNode.from_dict(params["root"], null, loaded)
		else:
			Logger.logg('Chat save file is missing "root" field.', Logger.WARN)
		return loaded
	return null
