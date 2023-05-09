class_name KoboldConfigPreset extends APIConfigPreset

@export var url : String = "http://127.0.0.1:5000/api"
@export var max_context_length : int = 2048
@export var max_length : int = 40
@export var rep_pen : float = 1.1
@export var rep_pen_range : int = 1024
@export var rep_pen_slope : float = 0.9
@export var temperature : float = 0.7
@export var tfs : float = 0.9
@export var top_a : float = 0
@export var top_k : float = 0
@export var top_p : float = 0.95
@export var multigeneration : bool = true
@export var keep_examples : bool = false
@export var single_line : bool = false
@export var use_story : bool = false
@export var use_world_info : bool = false
@export var sampler_order : Array = [6, 0, 1, 2, 3, 4, 5]

@export var kobold_memory : String = "{{description}}\nScenario: {{scenario}}"
@export var authors_note : String = "[{{char}} is {{personality}}]"
