# res://ui/quick_slot_ui.gd
extends Control

var _ability_system
var _panel: PanelContainer
var _icon: TextureRect
var _name_label: Label
var _cooldown_bar: ProgressBar
var _index_label: Label
var _flash: ColorRect
var _vbox: VBoxContainer


func _ready() -> void:
	pass


func init(system) -> void:
	_ability_system = system
	system.slot_changed.connect(_on_slot_changed)
	system.cooldown_updated.connect(_on_cooldown_updated)
	_build_single_slot()
	_refresh()


func _build_single_slot() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 4)
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_vbox)

	# Контейнер для иконки + вспышки
	var icon_container := Control.new()
	icon_container.custom_minimum_size = Vector2(112, 112)
	icon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(icon_container)

	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(_icon)

	# Вспышка поверх иконки
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_child(_flash)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_vbox.add_child(_name_label)

	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.min_value = 0.0
	_cooldown_bar.max_value = 1.0
	_cooldown_bar.value = 1.0
	_cooldown_bar.show_percentage = false
	_cooldown_bar.custom_minimum_size = Vector2(0, 5)
	_vbox.add_child(_cooldown_bar)

	_index_label = Label.new()
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.add_theme_font_size_override("font_size", 9)
	_index_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_vbox.add_child(_index_label)

	add_child(_panel)


func _play_flash() -> void:
	_flash.color = Color(1, 1, 1, 0.6)
	var tween = create_tween()
	tween.tween_property(_flash, "color", Color(1, 1, 1, 0), 0.2)


func _refresh() -> void:
	if _ability_system == null:
		return
	var ability = _ability_system.get_current_ability()
	var total = _ability_system.abilities.size()
	var idx = _ability_system.current_index

	if ability:
		_icon.texture = ability.icon
		_name_label.text = ability.ability_name
		_cooldown_bar.value = ability.get_cooldown_progress()
	else:
		_icon.texture = null
		_name_label.text = "—"
		_cooldown_bar.value = 1.0

	_index_label.text = "%d / %d" % [idx + 1, total]


func _on_slot_changed(_index: int, _ability) -> void:
	_play_flash()
	_refresh()


func _on_cooldown_updated(index: int, progress: float) -> void:
	if _ability_system and index == _ability_system.current_index:
		_cooldown_bar.value = progress
