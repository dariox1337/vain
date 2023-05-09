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
var message_queue := {}
enum State {PAUSE, UNPAUSE, STREAMING, WAITING_FOR_API_RESPONSE, WAITING_FOR_EDIT,
			REBUILDING_LOG_BACKWARDS, REBUILDING_LOG_FORWARD,
			SETTING_UP_FIRST_MESSAGE, DELETING_MESSAGES}
var current_state := State.PAUSE:
	set(new_state):
		current_state = new_state
		match current_state:
			State.PAUSE:
				$%UserInput.pause(true)
				$%UserInput.wait_indicator(false)
				if current_participant:
					current_participant.stop_generation()
				for key in message_queue.keys():
					if message_queue[key].message == "":
						message_queue[key].delete()
					message_queue.erase(key)
			_:
				$%UserInput.pause(false)


func _ready():
	chat_tree.participants_changed.connect(_on_participants_changed)
	current_node = chat_tree.root
	participants = chat_tree.participants
	if current_node == null:
		_on_participants_changed() # set up substitutions and apis used by participants
		current_state = State.SETTING_UP_FIRST_MESSAGE
	else:
		current_state = State.REBUILDING_LOG_FORWARD


func _process(_delta):
	match current_state:
		State.UNPAUSE:
			if current_node and current_participant:
				if message_queue == {} and current_node.message != "...":
					# This block is called when unpausing needs to call another participant.
					current_participant = get_next_participant(current_node.participant)
					request_new_message(current_node)
				else:
					# Otherwise, the system must be waiting for the last node to be edited
					current_state = State.WAITING_FOR_EDIT
					return
			current_state = State.WAITING_FOR_API_RESPONSE
		State.WAITING_FOR_EDIT:
			# This code executes only when User edits their message in a msg box
			if current_node.message != "...":
				current_state = State.WAITING_FOR_API_RESPONSE
				current_participant = get_next_participant(current_node.participant)
				request_new_message(current_node)
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
	if participants:
		# Connect to participant signals
		for part in participants:
			var callback = _on_participant_api_changed
			callback = callback.bind(part)
			if not part.is_connected("api_changed", callback):
				part.api_changed.connect(callback)
			if not part.is_connected("streaming_message_event", _on_streaming_message_event):
				part.streaming_message_event.connect(_on_streaming_message_event)
			_on_participant_api_changed(part)
		# Set the sustitution for {{user}}
		var user := Utils.get_chara_by_uid("000000000000000-aaaaaaaa")
		if user:
			chat_tree.chat_substitutions["{{user}}"] = user.name
	else:
		current_participant = null
	# If root has no children, it means the chat hasn't started yet.
	# Reset everything using the new list of participants
	# But don't run this code when rebuilding old message log
	#current_state != State.REBUILDING_LOG_FORWARD and\	(
	if chat_tree.root == null or chat_tree.root.get_child(0) == null:
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
	# Spawn nodes needed by participant-used apis.
	# But keep it at one instance per api if there are multiple characters using the same api
	if part.api not in used_apis:
		used_apis.append(part.api)
		spawn_api_nodes(part.api)


func request_new_message(parent: ChatTreeNode) -> void:
	if current_participant.api != "User":
		$%UserInput.wait_indicator(true)
	current_participant.gen_message(parent, chat_tree, _on_message_received)


func _on_message_received(part: ChatParticipant, result: APIResult,
							parent: ChatTreeNode) -> void:
	match result.status:
		APIResult.ERROR:
			Logger.logg("%s error: %s" % [part.api, result.message], Logger.ERROR)
			$WarningDialog.dialog_text = "%s error: %s" % [part.api, result.message]
			$WarningDialog.popup_centered()
			$WarningDialog.show()
			current_state = State.PAUSE
		APIResult.STREAM:
			if parent == current_node:
				current_node = new_message(part, result.message)
				message_queue[result.msg_uid] = current_node
				current_state = State.STREAMING
			elif current_state == State.WAITING_FOR_EDIT and parent == current_node.get_parent():
				current_node.message = result.message
				message_queue[result.msg_uid] = current_node
				current_state = State.STREAMING
			else: 
				Logger.logg("Received a message for a wrong chat branch.", Logger.ERROR)
		_:
			Logger.logg("Received an unexpected API message %s" % result.status, Logger.ERROR)


func _on_streaming_message_event(api_result: APIResult, part: ChatParticipant) -> void:
	if not message_queue.has(api_result.msg_uid):
		# Allow injecting user messages when paused
		if current_state == State.PAUSE and part.api == "User":
			current_participant = part
			current_node = new_message(part, "")
			message_queue[api_result.msg_uid] = current_node
			current_state = State.STREAMING
		else:
			if part.api == "User":
				Logger.logg("Wait for your turn.", Logger.WARN)
			else:
				Logger.logg("Received a message with unknown uid.", Logger.ERROR)
			return
	var node = message_queue[api_result.msg_uid]
	match api_result.status:
		APIResult.STREAM:
			node.message += api_result.message
		APIResult.STREAM_ENDED:
			$%UserInput.wait_indicator(false)
			node.message += api_result.message
			message_queue.erase(api_result.msg_uid)
			chat_tree.save()
			if current_state != State.PAUSE:
				current_state = State.WAITING_FOR_API_RESPONSE
				current_participant = get_next_participant(current_participant)
				request_new_message(current_node)
		APIResult.ERROR:
			Logger.logg("Streaming error: %s" % api_result.message, Logger.ERROR)
			$WarningDialog.dialog_text = "Streaming error.\n%s" % api_result.message
			$WarningDialog.popup_centered()
			$WarningDialog.show()
			current_state = State.PAUSE
		_:
			Logger.logg("Received an unexpected streaming message.", Logger.ERROR)
	if part.api == "User":
		$%UserInput.message_accepted() # Clears input field


func _on_warning_dialog_confirmed():
	if current_node and current_participant:
		# If current node is empty, it means the error happened when generating a choice.
		# Therefore, regenerate the same node
		if current_node.message == "...":
			request_new_message(current_node.get_parent())
			current_state = State.WAITING_FOR_EDIT
		# Else generate next message
		else:
			request_new_message(current_node)
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
			current_state = State.WAITING_FOR_EDIT
			current_participant = current_node.participant
			if current_participant.api != "User":
				request_new_message(current_node.get_parent())
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
		current_state = State.WAITING_FOR_API_RESPONSE
		current_participant = get_next_participant(current_node.participant)
		request_new_message(current_node)
	else:
		current_node.message = "..."
		current_state = State.WAITING_FOR_EDIT
		current_participant = current_node.participant
		request_new_message(current_node.get_parent())


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
