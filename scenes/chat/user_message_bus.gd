extends Node

signal new_user_message(message: String)

var sending_allowed := false

func user_message_typed(message: String) -> void:
	new_user_message.emit(message)
