extends Control
## SheetBar.gd — нарисованная полоса HUD (UI/sheet_hud.gd::setup_bar):
## рамка с ромбами, поверх неё в канале — тёмный след (отстающее значение) и
## заливка, обрезанные по доле. Те же поля, что у UI/HudBar.gd (ratio,
## delayed_ratio, fill_color, centered) — health_stamina_bar.gd пишет в них
## одинаково для обоих видов полосок.

var frame_tex: Texture2D
var fill_tex: Texture2D
var trail_tex: Texture2D
## Канал рамки в координатах полосы — сюда ложатся заливка и след
var channel := Rect2()
## Деталь поверх заливки (ромб посередине полосы концентрации)
var overlay_tex: Texture2D
var overlay_pos := Vector2.ZERO
## Заливка растёт от середины в обе стороны (концентрация)
var centered := false
## Красить ли заливку fill_color (концентрация: нейтральная заливка цвета
## шкалы). Иначе цвет заливки — как нарисован, fill_color не трогает её
var tint_fill := false
## Множитель цвета заливки при окраске: нейтральный след на листе тёмный
var tint_gain := 2.4
## Яркость заливки поверх нарисованного цвета (вспышка "не хватает Одра")
var fill_mod := Color.WHITE:
	set(v):
		fill_mod = v
		queue_redraw()

var ratio := 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, ratio):
			ratio = v
			queue_redraw()
var delayed_ratio := 0.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, delayed_ratio):
			delayed_ratio = v
			queue_redraw()
var fill_color := Color.WHITE:
	set(v):
		if v != fill_color:
			fill_color = v
			if tint_fill:
				queue_redraw()
# Поля HudBar.gd, которые ставит health_stamina_bar — здесь не нужны
var frame_color := Color.WHITE
var delayed_color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if frame_tex == null:
		return
	draw_texture(frame_tex, Vector2.ZERO)
	_layer(trail_tex, delayed_ratio, Color.WHITE)
	var mod := fill_mod
	if tint_fill:
		mod = Color(fill_color.r * tint_gain, fill_color.g * tint_gain, fill_color.b * tint_gain, fill_color.a) * fill_mod
	_layer(fill_tex, ratio, mod)
	if overlay_tex:
		draw_texture(overlay_tex, overlay_pos)


func _layer(t: Texture2D, r: float, mod: Color) -> void:
	if t == null or r <= 0.0:
		return
	var w := roundf(channel.size.x * r)
	var x0 := roundf((channel.size.x - w) * 0.5) if centered else 0.0
	draw_texture_rect_region(t, Rect2(channel.position + Vector2(x0, 0), Vector2(w, channel.size.y)),
			Rect2(x0, 0, w, channel.size.y), mod)
