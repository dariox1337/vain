extends Control


var apis: APIs = load("user://apis.tres")
var preset : KoboldConfigPreset


func _ready() -> void:
	var api : KoboldConfig = apis.list["Kobold"]
	preset = api.presets[api.last_used_preset]
	if not preset:
		# Switch to Default if the current preset is null
		api.last_used_preset = "Default"
		preset = api.presets[api.last_used_preset]
		if not preset:
			# Create a new one if Default is null
			preset = KoboldConfigPreset.new()
			api.presets[api.last_used_preset] = preset

	# Initialize API url
	$%UrlEdit.text = preset.url

	# Initialize checkboxes
	$%Multigeneration.set_pressed_no_signal(preset.multigeneration)
	$%KeepExamples.set_pressed_no_signal(preset.keep_examples)
	$%SingleLine.set_pressed_no_signal(preset.single_line)

	# Initialize token sliders
	$%MaxContext.value = preset.max_context_length
	$%MaxResponse.value = preset.max_length
	
	# Initialize repetition penalties
	$%RepPen.value = preset.rep_pen
	$%RepPenRange.value = preset.rep_pen_range
	$%RepPenSlope.value = preset.rep_pen_slope

	# Initialize samplers
	$%Temperature.value = preset.temperature
	$%TopK.value = preset.top_k
	$%TopP.value = preset.top_p
	$%TopA.value = preset.top_a
	$%TFS.value = preset.tfs
	
	# Initialize prompts
	$%Memory.text = preset.kobold_memory
	$%AuthorsNote.text = preset.authors_note


func _on_url_edit_text_changed(new_text):
	if new_text == "":
		preset.url = "http://127.0.0.1:5000/api"
	else:
		preset.url = new_text


func _on_max_context_changed(value):
	preset.max_context_length = value


func _on_max_response_changed(value):
	preset.max_length = value


func _on_rep_pen_changed(value):
	preset.rep_pen = value


func _on_rep_pen_range_changed(value):
	preset.rep_pen_range = value


func _on_rep_pen_slope_changed(value):
	preset.rep_pen_slope = value


func _on_temperature_changed(value):
	preset.temperature = value


func _on_top_k_changed(value):
	preset.top_k = value


func _on_top_p_changed(value):
	preset.top_p = value


func _on_top_a_changed(value):
	preset.top_a = value


func _on_tfs_changed(value):
	preset.tfs = value


func _on_multigeneration_toggled(button_pressed):
	preset.multigeneration = button_pressed


func _on_keep_examples_toggled(button_pressed):
	preset.keep_examples = button_pressed


func _on_single_line_toggled(button_pressed):
	preset.single_line = button_pressed
