class_name Logger extends RefCounted

enum {DEBUG, INFO, WARN, ERROR }

static func logg(message: String, level : int) -> void:
	var settings : GlobalSettings = load("user://settings.tres")
	if level >= settings.log_level:
		match level:
			DEBUG: print("DEBUG: ", message)
			INFO: print("INFO: ", message)
			WARN: print("WARNING: ", message)
			ERROR: print("ERROR: ", message)
