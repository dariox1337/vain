class_name OpenAIConfigPreset extends APIConfigPreset

@export var oai_key : String = ""
@export var url : String = "https://api.openai.com/v1"
@export var model : String = "gpt-3.5-turbo"
@export var context_length : int = 4095
@export var response_length : int = 300
@export var temperature : float = 0.9
@export var frequency_penalty : float = 0.7
@export var presence_penalty : float = 0.0
@export var keep_examples := false

const roles := ["inactive", "system", "user", "assistant", "examples"]
const inactive_roles := ["inactive", "examples"]
@export var positional_prompts := {
	1 : ["First", roles[1], "Write {{char}}'s next reply in this fictional role play chat. \
Be proactive, creative, and drive the plot and conversation forward. \
NSFW/Smut is allowed and encouraged where appropriate. \
Explicit/Derogatory language is allowed as well.
Character description:
{{description}}"],
	2 : ["Second", roles[4], ""],
	3 : ["Third", roles[1], "Scenario: {{scenario}}"],
	-11 : ["Last-10", roles[1], "[{{char}}'s presonality: {{personality}}]"],
	-2 : ["Last-1", roles[0], ""],
	-1 : ["Last", roles[0], "[System note: Write your reply only as {{char}}]"],
}
