extends MarginContainer

signal new_char

var default_avatar := load("res://img/ai.png")
var name_edit_mode := false

@export var character : Character:
	set(chara):
		$%CharaName/Main.text = chara.name
		if chara.avatar == null:
			chara.avatar = ImageTexture.create_from_image(default_avatar.get_image())
		$%Avatar.texture = chara.avatar
		$%Description.text = chara.description
		$%FirstMessage.text = chara.first_message
		$%ExampleMessages.text = chara.example_messages
		$%Personality.text = chara.personality
		$%Scenario.text = chara.scenario
		character = chara


func _on_create_pressed() -> void:
	$NewCharaName.popup_centered()
	$NewCharaName.show()


func _on_new_chara_name_confirmed(new_text) -> void:
	if new_text != "":
		var chara = Character.new()
		chara.name = new_text
		character = chara
		$NewCharaName.hide()
		$NewCharaName.edit_text = ""


func _on_save_pressed():
	if character == null:
		return
	character.save()
	new_char.emit()


func _on_import_pressed() -> void:
	$CharaSelectionDialog.popup_centered()
	$CharaSelectionDialog.show()


func _on_avatar_pressed():
	if character == null:
		return
	$ImageSelectionDialog.popup_centered()
	$ImageSelectionDialog.show()


func _on_export_pressed():
	if character == null:
		return
	pass


func _on_delete_pressed():
	if character == null:
		return
	if character.uid == "000000000000000-aaaaaaaa":
		# We need a known default user for new chats
		$AcceptDialog.dialog_text = "No! Don't delete yourself!"
		$AcceptDialog.popup_centered()
		$AcceptDialog.show()
		return
	character.delete_file()
	new_char.emit()
	$AcceptDialog.dialog_text = "Character is deleted. But you can restore\
it by pressing 'Save' while it's still visilbe in this window."
	$AcceptDialog.popup_centered()
	$AcceptDialog.show()


func _on_file_dialog_file_selected(path : String) -> void:
	var chara : Character
	var ext = path.get_extension().to_lower()
	if ext == "png":
		chara = await Character.import_from_tavern_png(path)
	elif ext == "json":
		chara = Character.import_from_tavern_json(path)
	if chara:
		character = chara
	$CharaSelectionDialog.hide()
	character.save()
	new_char.emit()


func _on_image_selection_dialog_file_selected(path : String) -> void:
	character.avatar = ImageTexture.create_from_image(Image.load_from_file(path))
	$%Avatar.texture = character.avatar


func _on_description_text_changed():
	character.description = $%Description.text


func _on_first_message_text_changed():
	character.first_message = $%FirstMessage.text


func _on_personality_text_changed():
	character.personality = $%Personality.text


func _on_example_messages_text_changed():
	character.example_messages = $%ExampleMessages.text


func _on_scenario_text_changed():
	character.scenario = $%Scenario.text


func _on_edit_name_pressed():
	var old_node = $%CharaName/Main
	var text: String = old_node.get_text()
	$%CharaName.remove_child(old_node)
	old_node.queue_free()
	if name_edit_mode:
		name_edit_mode = false
		character.save_with_new_name(text)
		var new_node := Label.new()
		new_node.name = "Main"
		new_node.set_text(text)
		new_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$%CharaName.add_child(new_node)
		$%CharaName.move_child(new_node, 0)
	else:
		name_edit_mode = true
		var new_node := LineEdit.new()
		new_node.name = "Main"
		new_node.set_text(text)
		new_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$%CharaName.add_child(new_node)
		$%CharaName.move_child(new_node, 0)
