extends MarginContainer

var settings: GlobalSettings = load("user://settings.tres")
var file_path : String


func draw_file(file, mini_size) -> void:
	custom_minimum_size = mini_size
	file_path = file
	$TextureButton.texture_normal = load(file_path)


func _on_texture_button_pressed():
	settings.background_img = file_path
