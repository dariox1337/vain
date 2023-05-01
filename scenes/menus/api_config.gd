extends Control

var apis : APIs = load("user://apis.tres")
@onready var api_menu := $%APIMenu
@onready var preset_menu := $%PresetMenu
@onready var config_container := $%ConfigContainer
@onready var new_preset_popup := $%NewPresetPopup
var loaded_config : Node

## Create popup menu items for apis
func _ready():
	## Create menu items for all apis
	var idx := 0
	for key in apis.list.keys():
		if key == "User":
			continue
		api_menu.add_item(key)
		api_menu.set_item_metadata(idx, key) # store api dictionary key as metadata
		if apis.last_used == key:
			api_menu.select(idx)
		idx = idx + 1
	switch_api()


func switch_api() -> void:
	switch_preset()


func switch_preset() -> void:
	var api : APIConfig = apis.list[apis.last_used]
	preset_menu.clear() # clear the list of presets for the previously used api
	# populate the list with new presets
	var idx := 0
	for key in api.presets.keys():
		preset_menu.add_item(key)
		preset_menu.set_item_metadata(idx, key) # store preset dictionary key as metadata
		if api.last_used_preset == key:
			preset_menu.select(idx)
		idx = idx + 1
	# remove the config window specific to the old api
	if loaded_config:
		config_container.remove_child(loaded_config)
	# load a new scene and add it as a child
	var config_scene = load(api.config_scene)
	loaded_config = config_scene.instantiate()
	config_container.add_child(loaded_config)


func _on_save_pressed() -> void:
	apis.save()


func _on_new_pressed() -> void:
	new_preset_popup.popup_centered()
	new_preset_popup.show()


func _on_new_preset_popup_confirmed(_new_text : String) -> void:
	var new_name: String = new_preset_popup.edit_text
	apis.list[apis.last_used].new_preset(new_name)
	apis.list[apis.last_used].last_used_preset = new_name
	new_preset_popup.edit_text = ""
	new_preset_popup.hide()
	apis.save()
	switch_preset()


func _on_del_pressed() -> void:
	var preset: String = preset_menu.get_item_text(preset_menu.selected)
	if preset == "Default":
		$AcceptDialog.dialog_text = "Default preset cannot be deleted."
		$AcceptDialog.popup_centered()
		$AcceptDialog.show()
	else:
		$ConfirmationDialog.popup_centered()
		$ConfirmationDialog.show()
		$ConfirmationDialog.dialog_text = "Do you really want to delete \"" + preset + "\" preset?"


func _on_confirmation_dialog_confirmed() -> void:
	var key: String = preset_menu.get_item_text(preset_menu.selected)
	apis.list[apis.last_used].presets.erase(key)
	apis.list[apis.last_used].last_used_preset = "Default"
	switch_preset()


func _on_api_menu_item_selected(index) -> void:
	var key: String = api_menu.get_item_metadata(index)
	apis.last_used = key
	switch_api()


func _on_preset_menu_item_selected(index) -> void:
	var key: String = preset_menu.get_item_metadata(index)
	apis.list[apis.last_used].last_used_preset = key
	switch_preset()
