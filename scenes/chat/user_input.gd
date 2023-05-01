extends HBoxContainer

signal pause_button_pressed(button)
signal deletion_mode_activated()
signal regeneration_requested()

var icon_pause := load("res://img/icons/pause-solid.svg")
var icon_play := load("res://img/icons/play-solid.svg")
var menu = ["Delete", "Regenerate"]


func _ready() -> void:
	var popup: PopupMenu = $MenuButton.get_popup()
	for item in menu:
		popup.add_item(item)
	popup.index_pressed.connect(_on_popup_index_pressed)


func pause(p: bool) -> void:
	if p:
		$%PauseButton.icon = icon_play
	else:
		$%PauseButton.icon = icon_pause
	$%PauseButton.set_pressed_no_signal(p)


func _on_play_button_pressed() -> void:
	if $%PauseButton.button_pressed:
		$%PauseButton.icon = icon_play
	else:
		$%PauseButton.icon = icon_pause
	pause_button_pressed.emit($%PauseButton.button_pressed)


func wait_indicator(show_indicator: bool) -> void:
	if show_indicator:
		$%WaitIndicator.show()
	else:
		$%WaitIndicator.hide()


func _on_popup_index_pressed(index: int) -> void:
	match menu[index]:
		"Delete":
			deletion_mode_activated.emit()
		"Regenerate":
			regeneration_requested.emit()
