extends PanelContainer

signal selected(participant)

@onready var part_menu = preload("res://scenes/menus/participant.tscn")
var selected_index : int = -1

func add_item(part: ChatParticipant) -> void:
	var new_part := part_menu.instantiate()
	new_part.part = part
	$VBox.add_child(new_part)
	new_part.selected.connect(_on_item_selected)

func clear() -> void:
	for child in $VBox.get_children():
		$VBox.remove_child(child)
		child.queue_free()
		selected_index = -1

func _on_item_selected(index) -> void:
	selected_index = index
	selected.emit($VBox.get_child(index).part)

func remove_selected() -> ChatParticipant:
	if selected_index >= 0:
		var child := $VBox.get_child(selected_index)
		var to_return: ChatParticipant = child.part
		$VBox.remove_child(child)
		child.queue_free()
		selected_index = -1
		return to_return
	return null
