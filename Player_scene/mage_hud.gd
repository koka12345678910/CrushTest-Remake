extends CanvasLayer
## mage_hud.gd — HUD мага (создаёт mage.gd в _ready): счётчик душ под
## портретом и рунная панель заклинаний справа внизу. Шкала Сейда — в общем
## HealthStaminaBar (enable_odr со своими цветами), здесь её нет. Вид — как
## у инвентаря (UI/clean_hud.gd).
##
## Души: значок-огонёк линиями и число — на месте счётчика золота других
## героев. Душа, долетевшая до мага в мире (gold_wisp.gd в режиме души),
## зовёт soul_collected — от мага к счётчику летит маленький огонёк, и число
## прибавляется, когда он долетел.
##
## Руны: четыре клетки — ЛКМ, ПКМ, V, B (огненный шар, огненное облако,
## импульс, столпы). Руна светлая, когда на заклинание хватает Сейда; не
## хватает — тусклая, а черта по низу клетки показывает, сколько уже
## накопилось. Колдуется — золотая кайма; каст — вспышка; не хватило —
## клетка вздрагивает.

const Clean := preload("res://UI/clean_hud.gd")

## Размеры — в макете 1920x1080 (stretch canvas_items), как у остальных HUD
const STONE := 80.0
const GAP := 14.0
## Низ клеток — вровень с клеткой быстрого слота (её низ в 65 px от края)
const MARGIN := Vector2(44, 65)
## Счётчик душ — там же, где золото у рыцаря и лучницы (Inventory/ui/hud.gd)
const SOULS_POS := Vector2(32, 150)

const SOUL_CORE := Color(0.88, 0.95, 1.0)
const SOUL_MID := Color(0.5, 0.72, 1.0)
const SOUL_EDGE := Color(0.2, 0.32, 0.75)
## Огонёк-значок — приглушённый холодный, в тон шкале Сейда
const SOUL_ICON := Color(0.6, 0.72, 0.88)

var _root: Control
var _soul_icon: Control
var _soul_label: Label
var _souls_shown := 0.0
var _souls_target := 0
## Души, которые уже засчитаны магу, но их огонёк ещё летит к счётчику
var _in_flight := 0
var _first_sync := true
var _runes: Array = []


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_souls()


func _process(delta: float) -> void:
	# Число догоняет счёт плавно — прибавка читается, а не щёлкает
	if _souls_shown < _souls_target:
		_souls_shown = minf(_souls_shown + maxf((_souls_target - _souls_shown) * 8.0, 12.0) * delta, _souls_target)
	elif _souls_shown > _souls_target:
		_souls_shown = float(_souls_target)
	_soul_label.text = str(int(_souls_shown))


# ===================== ДУШИ =====================

## Каждый кадр — настоящий счёт душ мага. Счётчик показывает его за вычетом
## тех, что ещё летят огоньком; трата (магазин) и загрузка сейва видны сразу
func sync_souls(total: int) -> void:
	_souls_target = maxi(total - _in_flight, 0)
	if _first_sync or _souls_shown > _souls_target:
		_souls_shown = float(_souls_target)
		_first_sync = false


## Душа впиталась в мага в точке world_pos: от неё к счётчику летит огонёк,
## по прилёту число растёт на amount (счёт мага уже вырос — см. sync_souls)
func soul_collected(world_pos: Vector2, amount: int) -> void:
	_in_flight += amount
	var from := get_viewport().get_canvas_transform() * world_pos
	var to := _soul_icon.global_position + _soul_icon.size * 0.5
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size = Vector2(18, 18)
	dot.pivot_offset = dot.size * 0.5
	dot.draw.connect(func():
		dot.draw_circle(dot.size * 0.5, 9.0, Color(SOUL_EDGE, 0.35))
		dot.draw_circle(dot.size * 0.5, 5.5, Color(SOUL_MID, 0.8))
		dot.draw_circle(dot.size * 0.5, 2.6, SOUL_CORE))
	_root.add_child(dot)
	dot.position = from - dot.size * 0.5
	# Летит дугой: сначала чуть вниз-в сторону, потом вверх в счётчик
	var mid := from.lerp(to, 0.35) + Vector2(randf_range(-60, 60), randf_range(60, 120))
	var t := dot.create_tween()
	t.tween_method(func(v: float):
		var p := from.lerp(mid, v).lerp(mid.lerp(to, v), v)
		dot.position = p - dot.size * 0.5
		dot.scale = Vector2.ONE * lerpf(1.0, 0.6, v), 0.0, 1.0, randf_range(0.45, 0.6)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func():
		dot.queue_free()
		_in_flight -= amount
		_bump_icon())


func _bump_icon() -> void:
	_soul_icon.scale = Vector2.ONE * 1.25
	_soul_icon.create_tween().tween_property(_soul_icon, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_soul_label.modulate = Color(1.3, 1.4, 1.6)
	_soul_label.create_tween().tween_property(_soul_label, "modulate", Color.WHITE, 0.35)


func _build_souls() -> void:
	_soul_icon = Clean.Glyph.new()
	_soul_icon.kind = "soul"
	_soul_icon.color = SOUL_ICON
	_soul_icon.size = Vector2(30, 30)
	_soul_icon.pivot_offset = _soul_icon.size * 0.5
	_soul_icon.position = SOULS_POS
	_root.add_child(_soul_icon)
	_soul_label = Clean.label("0", 23, Clean.TEXT)
	_soul_label.position = SOULS_POS + Vector2(38, 0)
	_soul_label.size = Vector2(150, 30)
	_soul_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_soul_label)


# ===================== РУНЫ =====================

## spells — массив словарей {key, cost, glyph} по порядку слева направо;
## right — отступ правого края панели от правого края экрана (правее —
## быстрый слот предметов)
func build_runes(spells: Array, right := MARGIN.x) -> void:
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 1.0
	anchor.anchor_right = 1.0
	anchor.anchor_top = 1.0
	anchor.anchor_bottom = 1.0
	_root.add_child(anchor)
	var n := spells.size()
	var x0 := -right - n * STONE - (n - 1) * GAP
	for i in n:
		var r := RuneStone.new()
		r.key = spells[i]["key"]
		r.cost = spells[i]["cost"]
		r.glyph = spells[i]["glyph"]
		r.position = Vector2(x0 + i * (STONE + GAP), -MARGIN.y - STONE)
		anchor.add_child(r)
		_runes.append(r)


## Каждый кадр: сколько Сейда, какая руна сейчас колдуется (-1 — никакая) и
## текущие цены (талисман может их снизить — число в уголке меняется)
func update_runes(seid: float, casting: int, costs: Array = []) -> void:
	for i in _runes.size():
		var r: RuneStone = _runes[i]
		if i < costs.size():
			r.cost = costs[i]
		r.fill = clampf(seid / r.cost, 0.0, 1.0) if r.cost > 0.0 else 1.0
		r.active = i == casting
		r.queue_redraw()


func rune_cast(i: int) -> void:
	if i >= 0 and i < _runes.size():
		_runes[i].flash()


func rune_denied(i: int) -> void:
	if i >= 0 and i < _runes.size():
		_runes[i].deny()


## Рунная клетка: тёмная плашка как клетка инвентаря, руна — линиями
class RuneStone extends Control:
	## Черта накопления Сейда — цвет шкалы Сейда (mage.gd::SEID_COLOR)
	const SEID := Color(0.45, 0.62, 0.85)

	var key := ""
	var cost := 10.0
	## Руна — ломаные в квадрате 0..1
	var glyph: Array = []
	var fill := 1.0
	var active := false
	var _flash := 0.0
	var _shake := 0.0
	var _t := 0.0
	var _box: StyleBoxFlat
	var _box_active: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(STONE, STONE)
		pivot_offset = size * 0.5
		_box = Clean.box()
		_box_active = Clean.box(4, Clean.FILL, Color(Clean.GOLD_HI, 0.85))

	func flash() -> void:
		_flash = 1.0

	func deny() -> void:
		_shake = 1.0

	func _process(delta: float) -> void:
		_t += delta
		if _flash > 0.0 or _shake > 0.0:
			_flash = move_toward(_flash, 0.0, delta * 3.0)
			_shake = move_toward(_shake, 0.0, delta * 4.0)
			scale = Vector2.ONE * (1.0 + 0.06 * _flash)
			queue_redraw()

	func _draw() -> void:
		var off := Vector2(sin(_t * 70.0) * 4.0 * _shake, 0.0)
		var r := Rect2(off, size)
		var is_ready := fill >= 1.0
		draw_style_box(_box_active if active else _box, r)
		if _flash > 0.0:
			draw_rect(r.grow(-2.0), Color(1, 1, 1, 0.3 * _flash))
		# Накопление Сейда до цены — черта по низу клетки (только пока не хватает)
		if not is_ready:
			var w := size.x - 10.0
			draw_line(off + Vector2(5, size.y - 5), off + Vector2(5 + w, size.y - 5), Color(0, 0, 0, 0.5), 3.0)
			draw_line(off + Vector2(5, size.y - 5), off + Vector2(5 + w * fill, size.y - 5), SEID, 3.0)
		# Руна: светлая — готова, тусклая — не хватает, золотая — колдуется
		var col := Clean.TEXT if is_ready else Color(Clean.TEXT_DIM, 0.7)
		if active:
			col = Clean.GOLD_HI
		_glyph(Rect2(off + size * 0.5 - Vector2(16, 19), Vector2(32, 38)), col, 2.5)
		# Цена — в уголке, клавиша — под клеткой
		var f := Clean.font()
		draw_string(f, off + Vector2(size.x - 34, 19), str(int(cost)), HORIZONTAL_ALIGNMENT_RIGHT, 28, 14,
				Clean.TEXT_DIM if is_ready else Color(Clean.TEXT_DIM, 0.55))
		draw_string(f, off + Vector2(0, size.y + 24), tr(key), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Clean.TEXT_DIM)

	func _glyph(box: Rect2, col: Color, w: float) -> void:
		for stroke in glyph:
			var pts := PackedVector2Array()
			for p in stroke:
				pts.append(box.position + (p as Vector2) * box.size)
			draw_polyline(pts, col, w, true)
