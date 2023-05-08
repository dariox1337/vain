class_name APIConfigPreset extends Resource

@export var stream := false

func get_preset_properties() -> Array[String]:
	return ["stream"]
