class_name Character extends Resource

@export var name : String
@export var uid := ""
var avatar : ImageTexture:
	get:
		if avatar:
			return avatar
		else:
			var char_avatar = Image.load_from_file("user://characters/%s_%s.png" % [uid, name])
			if char_avatar:
				return ImageTexture.create_from_image(char_avatar)
			return null
@export var description := ""
@export var first_message := ""
@export var example_messages := ""
@export var personality := ""
@export var scenario := ""
@export var talkativeness := 0.5


func _init():
	uid = Utils.gen_new_uid()


func save() -> void:
	var path = "user://characters/%s_%s" % [uid, name]
	var err = ResourceSaver.save(self, path + ".tres")
	if err != OK:
		Logger.logg("Code %s. Failed to save character file to %s" % [err, path], Logger.ERROR)
	err = avatar.get_image().save_png(path + ".png")
	if err != OK:
		Logger.logg("Code %s. Failed to save character avatar to %s" % [err, path], Logger.ERROR)


func save_with_new_name(new_name: String) -> void:
	var old_name = name
	name = new_name
	var dir = Utils.check_user_dir("user://characters/")
	if dir:
		dir.rename("user://characters/%s_%s.tres" % [uid, old_name],
					"user://characters/%s_%s.tres" % [uid, name])
		dir.rename("user://characters/%s_%s.png" % [uid, old_name],
					"user://characters/%s_%s.png" % [uid, name])


func delete_file() -> void:
	var dir = Utils.check_user_dir("user://characters/")
	if dir:
		dir.remove("user://characters/%s_%s.tres" % [uid, name])
		dir.remove("user://characters/%s_%s.png" % [uid, name])


static func import_from_tavern_json(global_file_path: String) -> Character:
	var chara := Character.new()
	var file := FileAccess.open(global_file_path, FileAccess.READ)
	var json_as_text := file.get_as_text()
	_populate_chara_from_json(json_as_text, chara)
	return chara


static func import_from_tavern_png(global_file_path: String) -> Character:
	var data = await PythonBridge.eval('core.get_chara_metadata("%s")' % global_file_path)
	if data == "":
		Logger.logg("No character description found.", Logger.WARN)
		return null
	# Build character card
	var chara := Character.new()
	chara.avatar = ImageTexture.create_from_image(Image.load_from_file(global_file_path))
	_populate_chara_from_json(data, chara)
	return chara


static func _populate_chara_from_json(data: String, chara: Character) -> Character:
	var json := JSON.new()
	json.parse(data)
	var parsed : Dictionary = json.get_data()
	Logger.logg(JSON.stringify(parsed, "    "), Logger.DEBUG)
	if parsed.has("create_date"):
		# make sure "create date" is recorded as unix time
		var regex = RegEx.create_from_string('[0-9]{10,15}')
		if regex.search(parsed["create_date"]):
			chara.uid = Utils.gen_new_uid(parsed["create_date"])
		else:
			chara.uid = Utils.gen_new_uid()
	else:
		chara.uid = Utils.gen_new_uid()
	var fields := {
		'name' : 'name',
		'description' : 'description',
		'first_mes' : 'first_message',
		'mes_example' : 'example_messages',
		'personality' : 'personality',
		'scenario' : 'scenario',
		}
	for key in fields.keys():
		if parsed.has(key):
			# Remove "\r" from "\r\n"
			var stripped_r: String = parsed[key].c_escape()
			stripped_r = stripped_r.replace("\\r", "")
			chara.set(fields[key], stripped_r.c_unescape())
	if parsed.has('talkativeness'):
		chara.talkativeness = float(parsed['talkativeness'])
	return chara
