class_name GlobalSettings extends Resource

## This resource contains global game settings

## REMINDER: don't call save() from setters because Godot calls the constructor on load, 
## which in turn will call save() and overwrite user-set values with default ones.

signal background_changed
signal chat_changed

@export var log_level := Logger.ERROR
@export var min_size := Vector2i(500, 500)
@export var background_img : String = "res://backgrounds/TAI-tavern.jpg":
	set(value):
		background_img = value
		background_changed.emit()
@export var chat_tree_uid := ""
var chat_tree : ChatTree = null:
	set(value):
		chat_tree = value
		chat_tree_uid = value.uid
		Logger.logg("Loaded chat %s_%s.json" % [value.uid, value.name], Logger.INFO)
		chat_tree.prune_deleted_participants()
		chat_changed.emit()
@export var default_chara_uid := "000000000000000-aaaaaaaa"
var default_chara : Character = Utils.get_chara_by_uid(default_chara_uid)


func save() -> void:
	var err = ResourceSaver.save(self, "user://settings.tres")
	if err != OK:
		Logger.logg("Code %s. Failed to save settings." % err, Logger.ERROR)
