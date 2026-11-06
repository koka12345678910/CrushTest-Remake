extends CanvasLayer
@onready var quick_slot_ui = $QuickSlotUI

const Clean := preload("res://UI/clean_hud.gd")

var gold_label: Label
var _gold_icon: Control

func init(system) -> void:
	quick_slot_ui.init(system)
	_build_gold_counter()

## Золото — под портретом (UI/health_stamina_bar.gd): значок-монета линиями,
## как значки категорий инвентаря, и число
func _build_gold_counter() -> void:
	_gold_icon = Clean.Glyph.new()
	_gold_icon.kind = "coin"
	_gold_icon.color = Clean.GOLD
	_gold_icon.position = Vector2(32, 150)
	_gold_icon.size = Vector2(30, 30)
	add_child(_gold_icon)
	gold_label = Clean.label("0", 23, Clean.TEXT)
	gold_label.position = Vector2(70, 150)
	gold_label.size = Vector2(150, 30)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Магу золото не нужно (mage.gd прячет счётчик) — значок прячется вместе с ним
	gold_label.visibility_changed.connect(func(): _gold_icon.visible = gold_label.visible)
	add_child(gold_label)

func update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = str(amount)
