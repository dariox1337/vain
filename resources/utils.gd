class_name Utils extends RefCounted


## Generate uid by taking unix time without ".",
## then add 3 random bytes, encoded as base64 and with "/" and "+" replaced
## Character cards already have creation time encoded in them. We can accept it optionally.
static func gen_new_uid(unix_time: String = "") -> String:
	if unix_time == "":
		unix_time = str(Time.get_unix_time_from_system())
	unix_time = unix_time.replace(".", "") # don't need that
	if unix_time.length() < 15:
		var need_more = 15 - unix_time.length()
		unix_time = unix_time + "0".repeat(need_more)
	elif unix_time.length() > 15:
		unix_time = unix_time.substr(0, 15)
	var crypto := Crypto.new()
	var rand := crypto.generate_random_bytes(6)
	var uid := unix_time + "-" + Marshalls.raw_to_base64(rand)
	uid = uid.replace("/", "W")
	uid = uid.replace("+", "4")
	
	return uid


static func get_datetime_from_filename(file_name: String) -> String:
	file_name = file_name.get_file()
	return get_datetime_from_uid(file_name)


static func get_datetime_from_uid(uid: String) -> String:
	var datetime := uid.substr(0,10)
	datetime = Time.get_datetime_string_from_unix_time(int(datetime))
	return datetime


static func check_user_dir(path : String) -> DirAccess:
	var err : Error
	var dir := DirAccess.open("user://")
	if not dir.dir_exists(path):
		err = dir.make_dir(path)
		if err != OK:
			Logger.logg(
				"Code: %s. Could not create %s directory." % [err, path],
				Logger.ERROR)
			return null
	err = dir.change_dir(path)
	if err != OK:
		Logger.logg(
			"Code: %s. Could not change directory to %s." % [err, path],
			Logger.ERROR)
		return null
	return dir


## Look for character in user://characters that matches uid
## (but actually any part of the file name will work)
static func get_chara_by_uid(uid: String) -> Character:
	var dir := check_user_dir("user://characters/")
	var chara : Character
	for file_name in dir.get_files():
		if uid in file_name:
			chara = load("user://characters/" + file_name.get_basename() + ".tres")
			return chara
	return null


static func get_chat_by_uid(uid: String) -> ChatTree:
	var dir := check_user_dir("user://chats/")
	for file_name in dir.get_files():
		if uid in file_name:
			var path = "user://chats/" + file_name.get_basename() + ".json"
			return ChatTree.load_from_file(path)
	return null


static func get_uid_from_file_name(file_name: String) -> String:
	return file_name.substr(0,24)


static func substitute(text: String, substitutions: Dictionary) -> String:
	for pattern in substitutions.keys():
		text = text.replacen(pattern, substitutions[pattern])
	return text
