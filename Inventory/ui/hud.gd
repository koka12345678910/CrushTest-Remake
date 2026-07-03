extends CanvasLayer
@onready var quick_slot_ui = $QuickSlotUI

var gold_label: Label

func init(system) -> void:
	quick_slot_ui.init(system)
	_build_gold_counter()

func _build_gold_counter() -> void:
	gold_label = Label.new()
	gold_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gold_label.position = Vector2(-150, 16)
	gold_label.size = Vector2(130, 30)
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.text = "0 G"
	add_child(gold_label)

func update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = str(amount) + " G"
