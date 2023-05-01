extends MarginContainer

signal changed(value)

@onready var label = $VBoxContainer/HBoxContainer/Label
@onready var slider = $VBoxContainer/HSlider
@onready var edit = $VBoxContainer/HBoxContainer/LineEdit
@onready var edit_regex = RegEx.new()
var old_text = ""

@export var text := "Slider":
	set(new_value):
		$VBoxContainer/HBoxContainer/Label.text = new_value
@export var value := 100.0:
	set(new_value):
		value = new_value
		$VBoxContainer/HSlider.set_value_no_signal(value)
		$VBoxContainer/HBoxContainer/LineEdit.text = str(value)
		$VBoxContainer/HBoxContainer/LineEdit.caret_column = str(value).length()
		old_text = str(value)
@export var range_min := 0.0:
	set(new_value):
		range_min = new_value
		$VBoxContainer/HSlider.min_value = new_value
@export var range_max := 100.0:
	set(new_value):
		range_max = new_value
		$VBoxContainer/HSlider.max_value = new_value
@export var step := 1.0:
	set(new_value):
		step = new_value
		$VBoxContainer/HSlider.step = new_value


func _ready():
	edit_regex.compile("^[0-9.]{0,5}$")


func _on_h_slider_value_changed(new_value):
	edit.text = str(new_value)
	value = new_value
	changed.emit(new_value)


func _on_line_edit_text_changed(new_text):
	if edit_regex.search(new_text):
		old_text = new_text
		value = float(new_text)
		slider.queue_redraw()
		changed.emit(value)
	else:
		edit.text = old_text
		edit.caret_column = old_text.length()
