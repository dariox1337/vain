extends MarginContainer

@onready var settings : GlobalSettings = load("user://settings.tres")
@onready var chara_list := $%CharaList
@onready var sheet := $%CharaSheet
@onready var chats_list := $%ChatsList
@onready var participants_list := $%ParticipantsList
var chara_path := "user://characters/"
var chats_path := "user://chats/"
var selected_chat : ChatTree


func _ready():
	scan_chats_dir()
	scan_chara_dir()


func _exit_tree():
	# Save settings when closing window
	selected_chat.scenario = $%Scenario.text
	selected_chat.save()
	settings.save()


func scan_chats_dir() -> void:
	var dir = Utils.check_user_dir(chats_path)
	if dir == null:
		return
	chats_list.clear()
	var files := dir.get_files()
	files.reverse()
	for file in files:
		if file.get_extension() == "json":
			var chat_name := file.get_slice("_", 1).get_basename()
			if chat_name == "":
				chat_name = Utils.get_datetime_from_filename(file)
			var index = chats_list.add_item(chat_name)
			chats_list.set_item_metadata(index, file)
			# compare uid to loaded chat
			if file.substr(0, 24) == settings.chat_tree_uid:
				chats_list.select(index)
				_on_chats_list_item_selected(index)


func scan_chara_dir() -> void:
	var dir = Utils.check_user_dir(chara_path)
	if dir == null:
		return
	chara_list.clear()
	for file in dir.get_files():
		if file.get_extension() == "tres":
			var full_path : String = chara_path + file
			var chara : Character = load(full_path)
			var icon : String = full_path.get_basename() + ".png"
			chara.avatar = ImageTexture.create_from_image(Image.load_from_file(icon))
			if chara.avatar == null:	# load default avatar if nothing found
				chara.avatar = ImageTexture.create_from_image(load("res://img/ai.png").get_image())
			var icon_loaded := chara.avatar
			var index = chara_list.add_item(chara.name, icon_loaded)
			chara_list.set_item_metadata(index, chara)
			await get_tree().process_frame


func _on_chara_list_item_clicked(index, _at_position, mouse_button_index):
	if mouse_button_index == 1:
		var chara = chara_list.get_item_metadata(index)
		sheet.character = chara


func _on_chara_sheet_new_char():
	scan_chara_dir()


func _on_new_chat_pressed():
	selected_chat.save()
	selected_chat = ChatTree.new()
	selected_chat.scenario_changed.connect(_on_scenario_changed)
	selected_chat.participant_joined(settings.default_chara)
	selected_chat.save()
	settings.chat_tree = selected_chat
	scan_chats_dir()
	chats_list.select(0)
	_on_chats_list_item_selected(0)
	# Switch to new chat immediately
	_on_load_chat_pressed()


func _on_chats_list_item_activated(_index):
	_on_load_chat_pressed()


func _on_load_chat_pressed():
	settings.chat_tree = selected_chat


func _on_rename_chat_pressed():
	$%RenameChatDialog.edit_text = selected_chat.name
	$%RenameChatDialog.popup_centered()
	$%RenameChatDialog.show()


func _on_rename_chat_dialog_confirmed(new_text):
	selected_chat.rename_and_save($%RenameChatDialog.edit_text)
	$%RenameChatDialog.edit_text = ""
	$%RenameChatDialog.hide()
	scan_chats_dir()


func _on_delete_chat_pressed():
	if chats_list.item_count == 1:
		Logger.logg("Can't delete the last chat.", Logger.WARN)
		return
	for idx in chats_list.get_selected_items():
		var chat_file: String = chats_list.get_item_metadata(idx)
		chats_list.remove_item(idx)
		var chat_uid: String = chat_file.substr(0,24)
		if idx < chats_list.item_count:
			chats_list.select(idx)
			_on_chats_list_item_selected(idx)
		else:
			chats_list.select(chats_list.item_count - 1)
			_on_chats_list_item_selected(chats_list.item_count - 1)
		# Switch chat if it's the one specified in settings.
		if chat_uid == settings.chat_tree_uid:
			_on_load_chat_pressed()

		var file: String = chats_path + chat_file
		Logger.logg("Deleting chat %s" % file, Logger.INFO)
		file = ProjectSettings.globalize_path(file)
		OS.move_to_trash(file)


func _on_chats_list_item_selected(index):
	# To edit currently loaded chat, we need to find a reference to it
	# because loading from file will create a separate copy.
	var file_name: String = chats_list.get_item_metadata(index)
	if settings.chat_tree != null and\
		settings.chat_tree.uid == Utils.get_uid_from_file_name(file_name):
		selected_chat = settings.chat_tree
	else:
		selected_chat = ChatTree.load_from_file(
			"user://chats/" + chats_list.get_item_metadata(index))
	if not selected_chat.is_connected("scenario_changed", _on_scenario_changed):
		selected_chat.scenario_changed.connect(_on_scenario_changed)
	selected_chat.prune_deleted_participants()
	$%Scenario.text = selected_chat.scenario
	participants_list.clear()
	if selected_chat.participants.size() > 0:
		for part in selected_chat.participants:
			participants_list.add_item(part)
		if selected_chat.participants.size() > 1:
			# Display first non-default character
			sheet.character = selected_chat.participants[1].chara
		else:
			# Display default character
			sheet.character = selected_chat.participants[0].chara


func _on_add_participant_pressed():
	if sheet.character:
		var new_part = selected_chat.participant_joined(sheet.character)
		if new_part:
			if $%Scenario.text == "":
				selected_chat.scenario = sheet.character.scenario
				$%Scenario.text = selected_chat.scenario
			selected_chat.save()
			participants_list.add_item(new_part)
		else:
			Logger.logg("Could not add a new participant. They must be already in the list.",
						Logger.DEBUG)


func _on_remove_participant_pressed():
	var removed : ChatParticipant = participants_list.remove_selected()
	if removed:
		selected_chat.participant_left(removed)
		selected_chat.save()


func _on_participants_list_selected(participant):
	sheet.character = participant.chara


func _on_scenario_changed():
	if selected_chat.scenario != $%Scenario.text:
		$%Scenario.text = selected_chat.scenario


func _on_scenario_text_changed():
	selected_chat.scenario = $%Scenario.text
