extends Node

var settings : GlobalSettings = load("user://settings.tres")
var apis : APIs = load("user://apis.tres")
var chat_scene := load("res://scenes/chat/chat.tscn")
var chat_window : Node

@onready var BackgroundConfig := load("res://scenes/menus/background_config.tscn")
@onready var ApiConfig := load("res://scenes/menus/api_config.tscn")
@onready var ChatConfig := load("res://scenes/menus/chat_config.tscn")
@onready var ChatMap := load("res://scenes/menus/chat_map.tscn")
@onready var config_windows := {"api": null, "background" : null, "ui": null,
								"map": null, "chat": null}

func _ready() -> void:
	DisplayServer.window_set_min_size(settings.min_size)
	load_last_chat()
	settings.chat_changed.connect(_on_chat_changed)


func _on_top_panel_menu_button_pressed(button : String) -> void:
	match button:
		"api":
			_on_top_panel_menu_button_pressed_implementation("api", ApiConfig)
		"background":
			_on_top_panel_menu_button_pressed_implementation("background", BackgroundConfig)
		"ui":
			pass
		"map":
			_on_top_panel_menu_button_pressed_implementation("map", ChatMap)
		"chat":
			_on_top_panel_menu_button_pressed_implementation("chat", ChatConfig)


func _on_top_panel_menu_button_pressed_implementation(key : String, scene : PackedScene) -> void:
	var was_open := false
	# Close other config windows before opening a new one
	for config in config_windows.keys():
		if config_windows[config]:
			if config == key:
				was_open = true
			$GUI.remove_child(config_windows[config])
			config_windows[config].queue_free()
			config_windows[config] = null
	if was_open == false:
		chat_window.current_state = chat_window.State.PAUSE
		config_windows[key] = scene.instantiate()
		config_windows[key].custom_minimum_size.x = settings.min_size.x
		if key == "map":
			config_windows[key].chat_tree = settings.chat_tree
			config_windows[key].node_selected.connect(_on_chat_node_selected)
		$GUI.add_child(config_windows[key])


func load_last_chat() -> void:
	var chat_tree : ChatTree
	if settings.chat_tree_uid != "":
		chat_tree = Utils.get_chat_by_uid(settings.chat_tree_uid)
	if chat_tree == null:
		chat_tree = ChatTree.new()
		chat_tree.participant_joined(settings.default_chara)
		chat_tree.save()
	settings.chat_tree = chat_tree
	load_chat()


func _on_chat_changed() -> void:
	$GUI.remove_child(chat_window)
	chat_window.queue_free()
	load_chat()


func load_chat() -> void:
	chat_window = chat_scene.instantiate()
	chat_window.chat_tree = settings.chat_tree
	chat_window.custom_minimum_size.x = settings.min_size.x
	$GUI.add_child(chat_window)
	$GUI.move_child(chat_window, 0)


func _on_chat_node_selected(node: ChatTreeNode) -> void:
	if chat_window:
		chat_window.jump_to_message(node)
