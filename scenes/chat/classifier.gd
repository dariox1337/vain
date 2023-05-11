extends Node

signal classification_result(result)

var apis = load("user://apis.tres")
var classification_msg_uid : String
var oai_classifier := {}
var oai_api: OpenAIConfig = apis.list["OpenAI"]
var oai_preset = ".classifier"


func classify(chat_node: ChatTreeNode) -> void:
	if oai_classifier == {}:
		init_oai_classifier()
	classify_with_oai(chat_node)


func init_oai_classifier() -> void:
	oai_api.streaming_event.connect(_on_oai_streaming_event)
	var preset: OpenAIConfigPreset
	if not oai_api.presets.has(oai_preset):
		oai_api.new_preset(oai_preset)
		preset = oai_api.presets[oai_preset]
		preset.temperature = 0.5
		preset.frequency_penalty = 0.0
		preset.presence_penalty = -0.5
		preset.stream = false
		preset.positional_prompts = {
		1 : ["First", preset.roles[1], """You're an expert model specializing on text \
classification according to the following criteria: admiration, amusement, anger, annoyance, \
approval, caring, confusion, curiosity, desire, disappointment, disapproval, disgust, \
embarrassment, excitement, fear, gratitude, grief, joy, love, nervousness, optimism, pride, \
realization, relief, remorse, sadness, surprise, neutral. Classify the user supplied excerpt by \
selecting three of the aforementioned emotions and assign scores to them."""],
		2 : ["Second", preset.roles[4], ""],
		3 : ["Third", preset.roles[0], ""],
		4 : ["Fourth", preset.roles[0], ""],
		5 : ["Fifth", preset.roles[0], ""],
		-11 : ["Last-10", preset.roles[0], ""],
		-2 : ["Last-1", preset.roles[0], ""],
		-1 : ["Last", preset.roles[0], ""],
		}
	else:
		preset = oai_api.presets[oai_preset]
	oai_classifier["preset"] = preset

	var classifier_chara := Character.new()
	classifier_chara.name = "Classifier"
	classifier_chara.example_messages = """
{{user}}: *One day you encounter a girl who appears to have fallen off her wheelchair due to an accident. Her wheelchair lies upside down a few inches away from her as she tries her best to crawl back to it.* Fuck my life... What do I do now? *She tries to lift the wheelchair back up, but she's too weak. After a few attempts she sighs seeming to curse her entire existence.* I'm stuck...
{{char}}: frustration: 0.54
sadness: 0.28
embarrassment: 0.18
"""
	var user_chara := Character.new()
	user_chara.name = "User"
	oai_classifier["classifier_chara"] = classifier_chara
	oai_classifier["user_chara"] = user_chara


func classify_with_oai(chat_node: ChatTreeNode) -> void:
	"""You're an expert model specialized on text classification according to the following criteria: admiration, amusement, anger, annoyance, approval, caring, confusion, curiosity, desire, disappointment, disapproval, disgust, embarrassment, excitement, fear, gratitude, grief, joy, love, nervousness, optimism, pride, realization, relief, remorse, sadness, surprise, neutral. Classify the user supplied excerp by selecting three of the aforementioned emotions and assign scores to them."""
	var temp_tree := ChatTree.new()
	var classifier := temp_tree.participant_joined(oai_classifier["classifier_chara"])
	var user := temp_tree.participant_joined(oai_classifier["user_chara"])
	
	var question := temp_tree.new_node(user, chat_node.message, null)
	classification_msg_uid = Utils.gen_new_uid()
	
	oai_api.gen_message(question, classifier, temp_tree, oai_preset, classification_msg_uid)


func _on_oai_streaming_event(api_result: APIResult) -> void:
	if api_result.msg_uid != classification_msg_uid:
		# This is a message for a different participant
		return
	print(api_result.message)
