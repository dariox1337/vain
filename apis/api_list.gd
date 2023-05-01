class_name APIs extends Resource

signal api_changed(old_api)

@export var last_used := "Kobold":
	set(new):
		var old = new
		last_used = new
		api_changed.emit(old)
@export var list := {
	"Kobold" : KoboldConfig.new(),
	"OpenAI" : OpenAIConfig.new(),
	"User"  : UserConfig.new(),
	}


func save() -> void:
	var err = ResourceSaver.save(self, "user://apis.tres")
	if err != OK:
		Logger.logg("Code %s. Failed to API settings." % err, Logger.ERROR)
