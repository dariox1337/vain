extends Node

## This scene is used to initalize settings

func _ready():
	randomize()
	
	if not FileAccess.file_exists("user://settings.tres"):
		var settings := GlobalSettings.new()
		settings.save()
	
	if not FileAccess.file_exists("user://apis.tres"):
		var apis := APIs.new()
		apis.save()
	else:
		# Check old file for missing new apis and add them and delete old ones
		var apis : APIs = load("user://apis.tres")
		var new_apis := APIs.new()
		for api in new_apis.list.keys():
			if not apis.list.has(api):
				apis.list[api] = new_apis.list[api]
				for old_api in apis.list.keys():
					if not new_apis.list.has(old_api):
						apis.list.erase(old_api)
				apis.save()
	
	# Create default player character if it doesn't exist
	if not Utils.get_chara_by_uid("000000000000000-aaaaaaaa"):
		var dir = Utils.check_user_dir("user://characters")
		assert(dir != null, "Can't edit user://characters/")
		var you = Character.new()
		you.name = "You"
		you.avatar = Image.load_from_file("res://img/user.png")
		you.uid = "000000000000000-aaaaaaaa"
		you.save()

	# Go to main game scene
	get_tree().change_scene_to_file("res://scenes/game_scene/game_scene.tscn")
	
