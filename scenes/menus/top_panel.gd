extends Control

signal menu_button_pressed(button: String)

func _on_background_menu_pressed() -> void:
	menu_button_pressed.emit("background")


func _on_api_menu_pressed():
	menu_button_pressed.emit("api")


func _on_character_pressed():
	menu_button_pressed.emit("chat")


func _on_ui_pressed():
	menu_button_pressed.emit("ui")


func _on_map_pressed():
	menu_button_pressed.emit("map")
