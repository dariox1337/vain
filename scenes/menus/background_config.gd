extends PanelContainer

## TODO: Add the function to import backgrounds 
## which means uploading new files to user:// and loading them together with default bgs

@export var settings: GlobalSettings = load("user://settings.tres")
@onready var bg_miniature := preload("res://scenes/menus/background_miniature.tscn")
@onready var list = $%ItemList
var path = "res://backgrounds/"

func _ready() -> void:
	var selected = settings.background_img
	# calculate column and icon size
	var fixed_x = max(size.x  / 4, 180) - 15
	var fixed_y = (fixed_x / 16) * 9
	list.fixed_column_width = fixed_x
	list.fixed_icon_size = Vector2(fixed_x, fixed_y)
	# Load files
	var dir = DirAccess.open(path)
	if not dir:
		Logger.logg("Could not open res://backgrounds/", Logger.ERROR)
		return
	var regex = RegEx.new()
	regex.compile("(jpg|png)$")

	for file_name in dir.get_files():
		if regex.search(file_name):
			var full_path = path + file_name
			var index = list.add_item(file_name, load(full_path))
			if full_path == selected:
				list.select(index)
			# wait for a frame to avoid blocking the thread for too long
			await get_tree().process_frame


func _on_item_list_item_clicked(index, _at_position, mouse_button_index):
	if mouse_button_index == 1:
		var file = path + list.get_item_text(index)
		settings.background_img = file

func _exit_tree():
	# Save settings when closing window
	settings.save()
