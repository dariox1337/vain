extends Control

## This is the main chat scene
## it takes input from the participants and generates message boxes

@onready var apis : APIs = load("user://apis.tres")
@onready var message_area := $%MessageArea
@onready var MessageBox := preload("res://scenes/chat/message_box.tscn")
var chat_tree : ChatTree
var used_apis : Array[String]
var participants : Array[ChatParticipant]
var current_participant : ChatParticipant
var current_node: ChatTreeNode = null
var message_queue := []
enum State {PAUSE, UNPAUSE, WAITING_FOR_EDIT, WAITING_FOR_API_RESPONSE,
			REBUILDING_LOG_BACKWARDS, REBUILDING_LOG_FORWARD, SETTING_UP_FIRST_MESSAGE,
			DELETING_MESSAGES}
var current_state := State.PAUSE
var waiting_for_edit_mode := false
var remote_api_active := false

func _ready():
	chat_tree.participants_changed.connect(_on_participants_changed)
	UserMessageBus.new_user_message.connect(_on_new_user_message_received)
	current_node = chat_tree.root
	participants = chat_tree.participants
	if current_node == null:
		_on_participants_changed() # set up substitutions and apis used by participants
		current_state = State.SETTING_UP_FIRST_MESSAGE
	else:
		current_state = State.REBUILDING_LOG_FORWARD


func _process(_delta):
	match current_state:
		State.PAUSE:
			$%UserInput.pause(true)
			if message_queue.size() > 0:
				var queued_message = message_queue.pop_front()
				if queued_message["parent"] == current_node:
					current_node = new_message(queued_message["participant"],
												queued_message["message"])
				elif waiting_for_edit_mode and\
					queued_message["participant"] == current_participant and\
					queued_message["parent"] == current_node.get_parent():
					current_node.message = queued_message["message"]
					waiting_for_edit_mode = false
				chat_tree.save()
				# Unpause if it was the user who wrote this message during pause
				if queued_message["participant"].api == "User":
					current_participant = queued_message["participant"]
					current_state = State.UNPAUSE
		State.UNPAUSE:
			$%UserInput.pause(false)
			if not remote_api_active and current_node != null and participants != []:
				current_participant = get_next_participant(current_participant)
				current_participant.gen_message(current_node, chat_tree, _on_message_received)
			current_state = State.WAITING_FOR_API_RESPONSE
		State.WAITING_FOR_EDIT:
			waiting_for_edit_mode = true
			if message_queue.size() > 0:
				var queued_message = message_queue.pop_front()
				# Use queued message to edit the current msg box
				if queued_message["participant"] == current_participant and\
					queued_message["parent"] == current_node.get_parent():
					current_node.message = queued_message["message"]
					chat_tree.save()
			if current_node.message != "...":
				$%UserInput.pause(false)
				current_participant = get_next_participant(current_node.participant)
				current_participant.gen_message(current_node, chat_tree, _on_message_received)
				waiting_for_edit_mode = false
				current_state = State.WAITING_FOR_API_RESPONSE
		State.WAITING_FOR_API_RESPONSE:
			if message_queue.size() > 0:
				var queued_message = message_queue.pop_front()
				# Check that the message isn't stale
				if queued_message["parent"] == current_node:
					current_node = new_message(queued_message["participant"],
												queued_message["message"])
					chat_tree.save()
					current_participant = get_next_participant(current_participant)
					current_participant.gen_message(current_node, chat_tree, _on_message_received)
		State.REBUILDING_LOG_FORWARD:
			_display_msg_box(current_node)
			if current_node.get_child(0):
				current_node = current_node.get_child(0)
			else:
				_on_participants_changed() # update substitutions and apis used by participants
				if current_node.participant:
					current_participant = current_node.participant
				current_state = State.PAUSE
		State.REBUILDING_LOG_BACKWARDS:
			_display_msg_box(current_node, true)
			if current_node.get_parent():
				current_node = current_node.get_parent()
			else:
				var msg_box = $%Messages.get_child(-1)
				current_node = msg_box.chat_node
				# remove last msg box because it'll be restored by the forward pass
				$%Messages.remove_child(msg_box)
				msg_box.queue_free()
				current_state = State.REBUILDING_LOG_FORWARD
		State.SETTING_UP_FIRST_MESSAGE:
			var root_node : ChatTreeNode
			for part in participants:
				current_participant = part
				if part.chara.first_message != "":
					# Replace {{char}} and {{user}} in the first message
					var first_message = part.chara.first_message.replacen("{{char}}",
																			part.chara.name)
					first_message = first_message.replacen("{{user}}", 
															chat_tree.get_user_substitution())
					root_node = new_message(part, first_message)
					break
				if chat_tree.scenario == "" and part.chara.scenario != "":
					chat_tree.scenario = part.chara.scenario
			if current_participant:
				current_participant = get_next_participant(current_participant)
			current_node = root_node
			current_state = State.PAUSE
		State.DELETING_MESSAGES:
			var current_msg_box := $%Messages.get_child(-1)
			if current_msg_box.is_selected():
				var parent_node_of_deleted: ChatTreeNode = current_msg_box.chat_node.delete()
				current_node = parent_node_of_deleted
				$%Messages.remove_child(current_msg_box)
				current_msg_box.queue_free()
				# Since the scheduler will switch to next participant when unpaused,
				# set current_participant to current_node_participant
				# and if that doesn't exist anymore (e.g. participant was deleted),
				# set it to the last participant, so the next called one will be the user
				if current_node.participant:
					current_participant = current_node.participant
				else:
					current_participant = chat_tree.participants[-1]
			else:
				_on_cancel_deletion_pressed()


func _on_participants_changed() -> void:
	# Spawn nodes needed by participant-used apis.
	# But keep it at one instance per api if there are multiple characters using the same api
	if participants:
		for part in participants:
			var callback = _on_participant_api_changed
			callback = callback.bind(part)
			if not part.is_connected("api_changed", callback):
				part.api_changed.connect(callback)
			if not part.is_connected("wait_state_entered", _on_wait_state_entered):
				part.wait_state_entered.connect(_on_wait_state_entered)
			_on_participant_api_changed(part)
		var user := Utils.get_chara_by_uid("000000000000000-aaaaaaaa")
		if user:
			chat_tree.chat_substitutions["{{user}}"] = user.name
	else:
		current_participant = null
	# If root has no children, it means the chat hasn't started yet.
	# Reset everything using the new list of participants.
	# But don't run this code when rebuilding old message log
	if current_state != State.REBUILDING_LOG_FORWARD and\
		(chat_tree.root == null or chat_tree.root.get_child(0) == null):
		chat_tree.scenario = ""
		chat_tree.root = null
		for child in $%Messages.get_children():
			$%Messages.remove_child(child)
			child.queue_free()
		current_state = State.SETTING_UP_FIRST_MESSAGE


func _on_participant_api_changed(part: ChatParticipant) -> void:
	# If set api doesn't exist, switch to User
	if not apis.list.has(part.api):
		part.api = "User"
	# If set preset doesn't exist, switch to Default
	if not apis.list[part.api].presets.has(part.preset):
		part.preset = "Default"
	if part.api not in used_apis:
		used_apis.append(part.api)
		spawn_api_nodes(part.api)


func _on_wait_state_entered(truefalse: bool) -> void:
	remote_api_active = truefalse
	$%UserInput.wait_indicator(truefalse)


func _on_message_received(part: ChatParticipant, result: APIResult, parent: ChatTreeNode) -> void:
	if result.status != APIResult.OK:
		Logger.logg("%s encountered an error." % part.api, Logger.ERROR)
		$WarningDialog.dialog_text = "Encountered an API error: %s" % result.message
		$WarningDialog.popup_centered()
		$WarningDialog.show()
		current_state = State.PAUSE
		return
	if result.message == "":
		Logger.logg("Received an empty message from participant %s. Discarding." % part.chara.name,
					Logger.INFO)
		return
	message_queue.push_back({"participant": part, "message": result.message, "parent": parent})


func _on_warning_dialog_confirmed():
	$%UserInput.pause(false)
	if not remote_api_active and current_node != null and participants != []:
		current_participant.gen_message(current_node, chat_tree, _on_message_received)
	current_state = State.WAITING_FOR_API_RESPONSE


## This functions generates a new ChatTreeNode given a chat participant and a message
func new_message(part: ChatParticipant, message: String) -> ChatTreeNode:
	# The reference to the last ChatTreeNode can be found inside the last msgbox
	var parent : ChatTreeNode = null
	if $%Messages.get_child_count() > 0:
		parent = $%Messages.get_child(-1).chat_node
	# if parent is null, the new node will be a root node
	var new_msg : ChatTreeNode = chat_tree.new_node(part, message, parent)
	_display_msg_box(new_msg)
	return new_msg


## This function takes a ChatTreeNode and instantiates a message box, adding it to the hierarchy.
func _display_msg_box(chat_node : ChatTreeNode, on_top := false) -> void:
	var spawned_message_box := MessageBox.instantiate()
	spawned_message_box.set_message(chat_node)
	$%Messages.add_child(spawned_message_box)
	if on_top:
		$%Messages.move_child(spawned_message_box, 0)
	# message boxes can send signals about swipes and selections
	spawned_message_box.branch_changed.connect(_on_branch_switched)
	spawned_message_box.selected.connect(_on_msg_box_selected)
	await get_tree().process_frame
	message_area.scroll_vertical = int(message_area.get_v_scroll_bar().max_value)


## Handler for MessageBox signals when user swipes
func _on_branch_switched(msg_box: PanelContainer) -> void:
	var children := $%Messages.get_children()
	var caller_child := children.find(msg_box)
	# Remove all subsequent messages belonging to the old branch
	for idx in range(caller_child+1, children.size()):
		$%Messages.remove_child(children[idx])
		children[idx].queue_free()
	if msg_box.chat_node.get_child(0):
		current_node = msg_box.chat_node.get_child(0)
		current_state = State.REBUILDING_LOG_FORWARD
	else:
		current_node = msg_box.chat_node
		if current_node.message == "...":
			current_participant = current_node.participant
			current_participant.gen_message(current_node.get_parent(), chat_tree, 
											_on_message_received)
			current_state = State.WAITING_FOR_EDIT
		else:
			current_state = State.PAUSE


## This function gets a list of nodes that the api needs
## and adds them as children to this scene.
func spawn_api_nodes(api: String) -> void:
	var to_adopt : Array[Node] = apis.list[api].adopt_children()
	for node in to_adopt:
		$APINodes.add_child(node)


func get_next_participant(participant: ChatParticipant) -> ChatParticipant:
	var index = participants.find(participant)
	var next_index = (index + 1) % participants.size()
	return participants[next_index]


func _on_user_input_pause_button_pressed(pause: bool) -> void:
	if pause:
		current_state = State.PAUSE
	else:
		if current_state == State.PAUSE:
			current_state = State.UNPAUSE


func _on_user_input_deletion_mode_activated() -> void:
	for msg_box in $%Messages.get_children():
		msg_box.selection_mode(true)
	$%DeleteModeButtons.show()
	$%UserInput.hide()
	current_state = State.PAUSE


func _on_msg_box_selected(msg_box: PanelContainer) -> void:
	var children := $%Messages.get_children()
	var caller_child := children.find(msg_box)
	for idx in range(0, caller_child):
		children[idx].deselect()
	for idx in range(caller_child+1, children.size()):
		children[idx].select()


func _on_delete_selected_messages_pressed() -> void:
	current_state = State.DELETING_MESSAGES


func _on_cancel_deletion_pressed() -> void:
	for msg_box in $%Messages.get_children():
		msg_box.selection_mode(false)
	$%DeleteModeButtons.hide()
	$%UserInput.show()
	current_state = State.PAUSE


func _on_user_input_regeneration_requested() -> void:
	if current_node.participant.api == "User":
		current_participant = get_next_participant(current_node.participant)
		current_participant.gen_message(current_node, chat_tree, _on_message_received)
		current_state = State.WAITING_FOR_API_RESPONSE
	else:
		current_node.message = "..."
		current_participant = current_node.participant
		current_participant.gen_message(current_node.get_parent(), chat_tree, _on_message_received)
		current_state = State.WAITING_FOR_EDIT


# Let user inject messages while paused
func _on_new_user_message_received(message: String) -> void:
	if current_state == State.PAUSE and message != "":
		# Find the first user participant and send the message as that participant
		for part in participants:
			if part.api == "User":
				message_queue.push_back({"participant": part,
										"message": message,
										"parent": current_node})
				break


func jump_to_message(node: ChatTreeNode) -> void:
	var children := $%Messages.get_children()
	var found : PanelContainer = null
	for child in children:
		if child.chat_node == node:
			found = child
			break
	if found:
		_on_branch_switched(found)
	else:
		for child in children:
			$%Messages.remove_child(child)
			child.queue_free()
		current_node = node
		current_state = State.REBUILDING_LOG_BACKWARDS
