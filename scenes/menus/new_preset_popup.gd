extends Popup

signal confirmed(new_text)


@export var label_text : String:
	set(new):
		$%Label.text = new
	get:
		return $%Label.text
@export var edit_text : String:
	set(new):
		$%Edit.text = new
	get:
		return $%Edit.text
@export var confirm_text := "Confirm":
	set(new):
		$%Confirm.text = new
	get:
		return $%Confirm.text
@export var cancel_text := "Cancel":
	set(new):
		$%Cancel.text = new
	get:
		return $%Cancel.text


func _on_cancel_pressed() -> void:
	$%Edit.text = ""
	hide()


func _on_confirm_pressed() -> void:
	confirmed.emit($%Edit.text)
