class_name ChatTreeNode extends Resource

signal message_edited

@export var participant : ChatParticipant = null
# Save names separately from the participant reference in case character card gets deleted, 
# so we can rebuild the log with names at least
@export var name : String
@export var message : String:
		set(new_message):
			message = new_message
			message_edited.emit()
@export var _children : Array[ChatTreeNode] = []
# The following vars can't be exported because they create infinite recursion
var _parent : ChatTreeNode = null
var _tree : ChatTree = null


# We need an empty node (_init) during loading, that's why there is a separate contructor
# for regular operations.
static func chat_new(tree: ChatTree, part: ChatParticipant, msg: String,
					parent: ChatTreeNode) -> ChatTreeNode:
	var new = ChatTreeNode.new()
	new.participant = part
	new.name = part.chara.name
	new.message = msg
	new._parent = parent
	new._tree = tree
	return new


func delete() -> ChatTreeNode:
	for child in _children:
		child.delete()
	if _parent:
		_parent.child_deleted(self)
	return _parent


func child_deleted(child: ChatTreeNode) -> void:
	_children.erase(child)


func get_parent() -> ChatTreeNode:
	return self._parent

func is_root() -> bool:
	if self._parent:
		return false
	else:
		return true


func get_next_sibling() -> ChatTreeNode:
	if is_root():
		return null
	else:
		var siblings = _parent._children
		var idx = siblings.find(self)
		if siblings.size() > idx+1:
			return siblings[idx+1]
		else:
			return null


func get_prev_sibling() -> ChatTreeNode:
	if is_root():
		return null
	else:
		var siblings = _parent._children
		return siblings[siblings.find(self)-1]


func get_my_index() -> int:
	if is_root():
		return 0
	else:
		return _parent._children.find(self)


func get_siblings_count() -> int:
	if is_root():
		return 1
	else:
		return _parent._children.size()


func get_child(idx: int) -> ChatTreeNode:
	if idx < _children.size():
		return _children[idx]
	else:
		return null


func get_children() -> Array[ChatTreeNode]:
	return _children


func gen_new_sibling() -> ChatTreeNode:
	if is_root():
		return null
	else:
		return _tree.new_node(participant, "...", _parent)


func get_chara_name() -> String:
	return name


func to_dict() -> Dictionary:
	var dict := {"name" : name, "message": message}
	if participant:
		dict["participant"] = participant.uid
	var children_dicts := []
	for child in _children:
		children_dicts.append(child.to_dict())
	dict["children"] = children_dicts
	return dict


static func from_dict(dict: Dictionary, parent: ChatTreeNode, tree: ChatTree) -> ChatTreeNode:
	var node := ChatTreeNode.new()
	node.name = dict["name"]
	node.message = dict["message"]
	node._tree = tree
	node._parent = parent
	if dict.has("participant"):
		for part in tree.participants:
			if dict["participant"] == part.uid:
				node.participant = part
	for child_dict in dict["children"]:
		var child := from_dict(child_dict, node, tree)
		node._children.append(child)
	return node
