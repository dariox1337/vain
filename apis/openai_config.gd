extends Control

var apis: APIs = load("user://apis.tres")

@onready var model_menu = $%ModelMenu
@onready var api_key_edit := $%ApiKeyEdit
@onready var address_edit := $%AddressEdit
@onready var context_length := $%ContextLength
@onready var response_length := $%ResponseLength
@onready var temperature := $%Temperature
@onready var frequency := $%FrequencyPenalty
@onready var presence := $%PresencePenalty
@onready var prompts := $%GridContainer

var default_url := "https://api.openai.com/v1"
var preset : OpenAIConfigPreset
var models := ["gpt-3.5-turbo", "gpt-3.5-turbo-0301", "gpt-4", "gpt-4-0314"]


func _ready() -> void:
	var api : OpenAIConfig = apis.list["OpenAI"]
	preset = api.presets[api.last_used_preset]
	if not preset:
		# Switch to Default if the current preset is null
		api.last_used_preset = "Default"
		preset = api.presets[api.last_used_preset]
		if not preset:
			# Create a new one if Default is null
			preset = OpenAIConfigPreset.new()
			api.presets[api.last_used_preset] = preset

	# Initialize models list
	if preset.model not in models:
		preset.model = models[0]
	var idx = 0
	for m in models:
		model_menu.add_item(m)
		if m == preset.model:
			model_menu.select(idx)
		idx = idx + 1
	
	# Initialize examples config
	$%Examples.set_pressed_no_signal(preset.keep_examples)

	# Initialize API key and url
	api_key_edit.text = preset.oai_key
	if preset.url != default_url:
		address_edit.text = preset.url
	
	# Initialize token sliders
	context_length.value = preset.context_length
	response_length.value = preset.response_length
	
	# Initialize temperature, freq, and presence
	temperature.value = preset.temperature
	frequency.value = preset.frequency_penalty
	presence.value = preset.presence_penalty
	
	# Initialize prompt config
	$%PromptConfig.init_prompt_config(preset.positional_prompts, preset.roles,
										preset.inactive_roles)


func _on_model_menu_item_selected(_index) -> void:
	preset.model = model_menu.text


func _on_api_key_edit_text_changed(new_text) -> void:
	preset.oai_key = new_text


func _on_address_edit_text_changed(new_text) -> void:
	if new_text == "":
		preset.url = default_url
	else:
		preset.url = new_text


func _on_context_length_changed(value : float) -> void:
	preset.context_length = int(value)


func _on_response_length_changed(value : float) -> void:
	preset.response_length = int(value)


func _on_temperature_changed(value : float) -> void:
	preset.temperature = value


func _on_frequency_penalty_changed(value : float) -> void:
	preset.frequency_penalty = value


func _on_presence_penalty_changed(value : float) -> void:
	preset.presence_penalty = value


func _on_examples_toggled(button_pressed : bool) -> void:
	preset.keep_examples = button_pressed
