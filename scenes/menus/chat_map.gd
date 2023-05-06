extends Control

signal node_selected(ChatTreeNode)

@export var chat_tree : ChatTree


func _ready() -> void:
	if chat_tree.root == null:
		return
	var offset = Vector2(50.0, 50.0)
	_set_up_node(chat_tree.root, offset)
	#$%Graph.arrange_nodes() # this method crashes often


## Recursive function that draws one graph node and calls itself on chat_node's children
func _set_up_node(chat_node: ChatTreeNode, offset: Vector2i) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.position_offset = offset
	graph_node.title = chat_node.name
	# Input slot
	if not chat_node.is_root():
		var input_slot := Control.new()
		graph_node.add_child(input_slot)
		graph_node.set_slot_enabled_left(0, true)
	
	var message := Label.new()
	message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message.custom_minimum_size.x = 200
	message.max_lines_visible = 1
	message.text = chat_node.message
	graph_node.add_child(message)
	
	graph_node.set_meta("chat", chat_node)
	
	# Call chat_node's children
	$%Graph.add_child(graph_node)
	var children: Array[ChatTreeNode] = chat_node.get_children()
	if children.size() != 0:
		var output_slot = Control.new()
		graph_node.add_child(output_slot)
		graph_node.set_slot_enabled_right(0, true)
		var child_offset_x := offset.x + 300.0
		for child in children:
			var child_offset_y := offset.y + children.find(child) * 100.0
			var child_graph_node := _set_up_node(child, Vector2(child_offset_x, child_offset_y))
			$%Graph.connect_node(graph_node.name, 0, child_graph_node.name, 0)
	return graph_node


func _on_graph_node_selected(node):
	if node.has_meta("chat"):
		node_selected.emit(node.get_meta("chat"))
