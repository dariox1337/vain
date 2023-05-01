extends MarginContainer

signal selected(index)

@onready var apis : APIs
@export var part: ChatParticipant:
	set(new): 
		$%CharaName.text = new.chara.name
		part = new
		for api in apis.list.keys():
			$%APIOptions.add_item(api)
			if api == new.api:
				var idx = $%APIOptions.item_count
				$%APIOptions.select(idx-1)
		rebuild_preset_list()


func _init():
	apis = load("user://apis.tres")


func _on_button_pressed():
	selected.emit(get_index())


func _on_api_options_item_selected(index):
	part.api = $%APIOptions.get_item_text(index)
	rebuild_preset_list()


func _on_preset_options_item_selected(index):
	part.preset = $%PresetOptions.get_item_text(index)


func rebuild_preset_list():
	$%PresetOptions.clear()
	for preset in apis.list[part.api].presets.keys():
		$%PresetOptions.add_item(preset)
		if preset == part.preset:
			var idx = $%PresetOptions.item_count
			$%PresetOptions.select(idx-1)
