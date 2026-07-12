extends DirectionalLight2D

@onready var lightning_flash: ColorRect = get_tree().get_root().get_node("Level01/Player2/Camera2D/CanvasLayer/LightningFlash")

@export var lightning_interval_min := 5.0
@export var lightning_interval_max := 15.0
@export var night_energy := 1.0 # обычное ночное освещение — поставь своё значение

var lightning_timer := 0.0
var next_lightning_time := 0.0

func _ready() -> void:
	next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)

func _process(delta: float) -> void:
	lightning_timer += delta
	if lightning_timer >= next_lightning_time:
		lightning_timer = 0.0
		next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)
		_trigger_lightning()

func _trigger_lightning() -> void:
	var flash_count = randi_range(2, 4)
	for i in flash_count:
		await _flash()
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout

func _flash() -> void:
	var tween = create_tween()
	tween.tween_property(self, "energy", 3.0, 0.02)
	tween.tween_property(self, "energy", night_energy, 0.08)

	if lightning_flash:
		var flash_tween = create_tween()
		flash_tween.tween_property(lightning_flash, "color:a", 0.5, 0.02)
		flash_tween.tween_property(lightning_flash, "color:a", 0.0, 0.08)

	await tween.finished
