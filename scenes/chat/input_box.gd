extends TextEdit


func _ready() -> void:
	grab_focus()


func _gui_input(event) -> void:
	if event.is_action_pressed("new_line"):
		insert_text_at_caret("\n")
	elif event.is_action_pressed("ui_text_submit"):
		if UserMessageBus.sending_allowed:
			UserMessageBus.user_message_typed(get_text())
			clear()
			accept_event()


func _on_text_changed():
	if get_total_visible_line_count() > 7:
		scroll_fit_content_height = false
		custom_minimum_size.y = 200
	else:
		scroll_fit_content_height = true
		custom_minimum_size.y = 0
