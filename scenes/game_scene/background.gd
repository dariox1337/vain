extends AspectRatioContainer

var settings: GlobalSettings = load("user://settings.tres")

func _ready() -> void:
	settings.background_changed.connect(_on_background_changed)
	change_background(settings.background_img)

func _on_background_changed() -> void:
	change_background(settings.background_img)

func change_background(file : String) -> void:
	$TextureRect.texture = load(file)
