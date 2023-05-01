extends PanelContainer

## Message box for a single message

## Signal when changing branches. Sends references to self.
## The signal receiver can see what chat_node is displayed by using this reference.
signal branch_changed(PanelContainer)
## Signal used for selecting msg boxes when deleting messages
signal selected(PanelContainer)

var chat_node: ChatTreeNode
var edit_mode := false

## When given a msg, draw it, using the scene nodes
## and update the reference to the ChatTreeNode shown in this message box
func set_message(msg: ChatTreeNode) -> void:
	chat_node = msg
	var user_name := $%UserName
	var message_body := $%Body/MessageBody
	user_name.set_text(chat_node.name)
	message_body.set_text(chat_node.message)
	if chat_node.get("participant"):
		$%Avatar.texture = chat_node.participant.chara.avatar
	if not chat_node.is_connected("message_edited", _on_node_message_edited):
		chat_node.message_edited.connect(_on_node_message_edited)
	
	# Hide swipe buttons for the root message
	if chat_node.is_root():
		var prev_button := $%PrevButton
		var next_button := $%NextButton
		prev_button.visible = false
		next_button.visible = false
	
	# Hide swipe counter when there are no siblings
	var sib = chat_node.get_siblings_count()
	if sib > 1:
		var sibling_counter := $%SiblingsCounter
		sibling_counter.visible = true
		sibling_counter.set_text("%s/%s" % [chat_node.get_my_index()+1, sib])


func _on_node_message_edited() -> void:
	$%Body/MessageBody.set_text(chat_node.message)


## Handler for "swipe right" signal
## If this msg item has no siblings to the right, e.g. it's sib3 in this [sib1, sib2, sib3],
## then it generates a new sibling (sib4),
## then updates the reference to chat_node drawn in this message box,
## informs interested parties about branch changes (chat is interested)
## finally, it draws new content with set_message
func _on_next_button_pressed() -> void:
	if chat_node.message == "...":
		return
	if edit_mode:
		_on_edit_pressed() # leave edit
	var new_item = chat_node.get_next_sibling()
	if not new_item:	# no siblings found to the right
		new_item = chat_node.gen_new_sibling()
		if not new_item:	# couldn't generate new sibling because this node is probably root 
			return
	chat_node = new_item
	branch_changed.emit(self)
	set_message(chat_node)

## Handler for "swipe left" signal
## It never generates new replies, but only wraps to the end.
## Still, it needs to inform interested parties about branch changes,
## then draw new content with set_message
func _on_prev_button_pressed() -> void:
	if edit_mode:
		_on_edit_pressed() # leave edit
	# get_prev_siblings wraps to the end of the list of siblings
	chat_node = chat_node.get_prev_sibling()
	branch_changed.emit(self)
	set_message(chat_node)

## Handler for Edit button when user wants to edit the message in place
func _on_edit_pressed() -> void:
	# Remove old node (either RichTextLabel or TextEdit)
	var old_node = $%Body/MessageBody
	var text: String = old_node.get_text()
	$Foreground/Body.remove_child(old_node)
	old_node.queue_free()
	
	if edit_mode:
		# Leave edit_mode and create RichTextLabel
		edit_mode = false
		var new_node := RichTextLabel.new()
		new_node.name = "MessageBody"
		new_node.set_text(text)
		new_node.fit_content = true
		new_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		$Foreground/Body.add_child(new_node)
		chat_node.message = text
	else:
		# Enter edit_mode and create TextEdit
		edit_mode = true
		var new_node := TextEdit.new()
		new_node.name = "MessageBody"
		new_node.set_text(text)
		new_node.scroll_fit_content_height = true
		new_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		new_node.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
		$Foreground/Body.add_child(new_node)


func selection_mode(toggle: bool) -> void:
	if toggle == true and not chat_node.is_root():
		deselect()
		$%SelectionCheckBox.show()
	else:
		$%SelectionCheckBox.hide()


func select() -> void:
	$%SelectionCheckBox.set_pressed_no_signal(true)


func deselect() -> void:
	$%SelectionCheckBox.set_pressed_no_signal(false)


func is_selected() -> bool:
	return $%SelectionCheckBox.button_pressed


func _on_selection_check_box_pressed() -> void:
	selected.emit(self)
