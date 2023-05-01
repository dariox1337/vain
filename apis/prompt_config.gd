extends Control


func init_prompt_config(prompts: Dictionary, roles: Array, inactive_roles: Array) -> void:
	var callback : Callable
	var keys = prompts.keys()
	keys.sort()
	var sorted_prompts := keys.filter(func(number): return number > 0)
	sorted_prompts.append_array(keys.filter(func(number): return number < 0))
	for prompt_key in sorted_prompts:
		var new_label := Label.new()
		new_label.text = prompts[prompt_key][0]
		$%GridContainer.add_child(new_label)

		var new_role_menu := OptionButton.new()
		for role in roles:
			new_role_menu.add_item(role)
			if role == prompts[prompt_key][1]:
				new_role_menu.select(roles.find(role))

		# Connect to the signal and bind arguments to know the caller
		callback = _on_positional_prompt_role_updated
		callback = callback.bind(prompt_key, new_role_menu, prompts, inactive_roles)
		new_role_menu.item_selected.connect(callback)
		$%GridContainer.add_child(new_role_menu)

		var new_text_edit := TextEdit.new()
		new_text_edit.scroll_fit_content_height = true
		new_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		new_text_edit.text = prompts[prompt_key][2]
		callback = _on_positional_prompt_role_updated
		callback = callback.bind(-1, prompt_key, new_text_edit, prompts, inactive_roles)
		new_text_edit.text_changed.connect(callback)
		$%GridContainer.add_child(new_text_edit)
		# Mute colors of inactive roles to indicate that the text field is not used
		if prompts[prompt_key][1] in inactive_roles:
			new_text_edit.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _on_positional_prompt_role_updated(index : int, prompt_key : int,
										caller : Control, prompts : Dictionary, 
										inactive_roles : Array) -> void:
	if index == -1: # Text changed
		prompts[prompt_key][2] = caller.text
	else: # Role changed
		prompts[prompt_key][1] = caller.get_item_text(index)
		var text_edit : Control = $%GridContainer.get_child(caller.get_index()+1)
		if caller.get_item_text(index) in inactive_roles:
			text_edit.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			text_edit.remove_theme_color_override("font_color")
