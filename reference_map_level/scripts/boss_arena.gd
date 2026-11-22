extends Node
## boss_arena.gd — бой с боссом во дворе храма Бальдра (узел BossArena у
## корня reference_map).
##
##   * Герой зашёл во двор глубже ворот — ворота запечатывает туман Тёмного
##     Солнца (коллизия + шейдер), босс ревёт и идёт в бой, внизу экрана —
##     его имя, полоса здоровья и полоса концентрации.
##   * Герой пал — бой сбрасывается: босс возвращается на место с полным
##     здоровьем, туман уходит, полоса прячется. Герой встаёт у костра
##     (Net._death_tick, в одиночной игре тоже).
##   * Босс повержен — туман рассеивается, «ВРАГ ПОВЕРЖЕН», затем конец
##     демо (demo_end.gd): затемнение, «ДЕМО ОКОНЧЕНО», главное меню.
## Босс — Objects/Boss_Crusader (enemy/humans/crusader/crusader_boss.tscn).

@export var boss_path := NodePath("../Objects/Boss_Crusader")
## Двор: внутри него (и выше линии запечатывания) бой начинается
@export var arena := Rect2(785, 900, 620, 345)
@export var seal_y := 1205.0
## Проём ворот (коллизия тумана)
@export var gate := Rect2(1035, 1224, 110, 38)
## Картинка тумана: основание (низ проёма) и размер
@export var fog_base := Vector2(1090, 1263)
@export var fog_size := Vector2(128, 112)
## Через сколько после победы начинается финал демо (demo_end.gd), с
@export var demo_end_delay := 5.6

const DemoEnd := preload("res://reference_map_level/scripts/demo_end.gd")

enum Phase { WAIT, FIGHT, DONE }

var phase := Phase.WAIT
var _boss: Node2D
var _gate_body: StaticBody2D
var _gate_shape: CollisionShape2D
var _fog: Node2D
var _bar: BossBar
var _layer: CanvasLayer


func _ready() -> void:
	_boss = get_node_or_null(boss_path) as Node2D
	if _boss == null:
		push_warning("[BossArena] нет босса %s" % boss_path)
		set_physics_process(false)
		return
	_boss.connect("defeated", _on_defeated)
	_boss.connect("phase_changed", func(p): if _bar: _bar.flash_phase(p))
	_build_gate()
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_bar = BossBar.new()
	_bar.boss = _boss
	_layer.add_child(_bar)


func _build_gate() -> void:
	var level := get_parent()
	_gate_body = StaticBody2D.new()
	_gate_body.name = "BossGate"
	_gate_body.collision_layer = 1
	_gate_body.collision_mask = 0
	_gate_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = gate.size
	_gate_shape.shape = r
	_gate_shape.position = gate.get_center()
	_gate_shape.disabled = true
	_gate_body.add_child(_gate_shape)
	level.add_child.call_deferred(_gate_body)
	_fog = FogWall.new()
	_fog.name = "BossFog"
	_fog.position = fog_base
	_fog.set("size", fog_size)
	_fog.modulate.a = 0.0
	_fog.visible = false
	var objects := level.get_node_or_null("Objects")
	(objects if objects else level).add_child.call_deferred(_fog)


func _hero() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(_delta: float) -> void:
	var hero := _hero()
	if hero == null or not is_instance_valid(_boss):
		return
	var dead: bool = hero.has_method("is_dead") and hero.is_dead()
	match phase:
		Phase.WAIT:
			if not dead and arena.has_point(hero.global_position) and hero.global_position.y < seal_y \
					and not _boss.get("is_dead"):
				_start()
		Phase.FIGHT:
			if dead:
				_reset()


func _start() -> void:
	phase = Phase.FIGHT
	_seal(true)
	_boss.call("start_fight")
	_bar.show_bar()


func _reset() -> void:
	phase = Phase.WAIT
	_boss.call("reset_fight")
	_bar.hide_bar()
	# Туман уходит, когда герой уже встал у костра
	get_tree().create_timer(2.0).timeout.connect(func(): if phase == Phase.WAIT: _seal(false))


func _on_defeated() -> void:
	phase = Phase.DONE
	var ui = load("res://Levels/bonfire/bonfire_ui.gd").of(get_tree())
	get_tree().create_timer(1.6).timeout.connect(func():
		_seal(false)
		_bar.hide_bar()
		if ui and ui.has_method("show_banner"):
			ui.show_banner(tr("ВРАГ ПОВЕРЖЕН")))
	# Надпись отыграла — конец демо
	get_tree().create_timer(demo_end_delay).timeout.connect(_demo_end)


## Финал демо: мир уходит в темноту, «ДЕМО ОКОНЧЕНО», дальше — главное меню
func _demo_end() -> void:
	var tree := get_tree()
	if tree == null or tree.root.get_node_or_null("DemoEnd"):
		return
	var s: Node = DemoEnd.new()
	s.name = "DemoEnd"
	tree.root.add_child(s)


func _seal(on: bool) -> void:
	_gate_shape.set_deferred("disabled", not on)
	var tw := create_tween()
	if on:
		_fog.visible = true
		tw.tween_property(_fog, "modulate:a", 1.0, 0.8)
	else:
		tw.tween_property(_fog, "modulate:a", 0.0, 1.2)
		tw.tween_callback(func(): _fog.visible = false)


# ───────────────────────── туман в воротах ─────────────────────────

## Завеса Тёмного Солнца в проёме ворот: дым клубится вверх, сквозь него
## тлеют кроваво-красные прожилки, у земли — угли. Светится сама (unshaded,
## premul) — читается и глубокой ночью; края мягкие, без рамки
class FogWall extends Node2D:
	const FOG_SHADER := """
	shader_type canvas_item;
	render_mode unshaded, blend_premul_alpha;

	uniform vec2 size = vec2(120.0, 96.0);
	varying vec2 local;

	float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
	float noise(vec2 p) {
		vec2 i = floor(p);
		vec2 f = fract(p);
		f = f * f * (3.0 - 2.0 * f);
		return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
	}
	float fbm(vec2 p) {
		float v = 0.0;
		float a = 0.5;
		for (int i = 0; i < 3; i++) {
			v += a * noise(p);
			p *= 2.03;
			a *= 0.5;
		}
		return v;
	}

	void vertex() {
		local = VERTEX;
	}

	void fragment() {
		// 0..1 по ширине, 0 — земля, 1 — верх завесы
		vec2 uv = vec2(local.x / size.x + 0.5, -local.y / size.y);
		float t = TIME;
		vec2 q = vec2(uv.x * 1.6, uv.y * 1.3 - t * 0.32);
		float w = fbm(q + vec2(fbm(q * 1.4 + t * 0.12), fbm(q * 1.1 - t * 0.08)) * 1.1);
		float sx = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x);
		float sy = smoothstep(1.0, 0.35, uv.y) * smoothstep(0.0, 0.06, uv.y);
		float body = sx * sy;
		// Дым: густой внизу, редеет кверху
		float smoke = body * clamp(0.62 + (w - 0.5) * 1.3 - uv.y * 0.25, 0.0, 1.0);
		// Прожилки света: тонкие гребни шума
		float ridge = 1.0 - abs(w * 2.0 - 1.0);
		float vein = smoothstep(0.8, 0.99, ridge) * body * (0.6 + 0.4 * sin(t * 1.7 + uv.y * 6.0));
		// Угли у земли
		float ember = smoothstep(0.35, 0.0, uv.y) * sx * smoothstep(0.55, 0.8, fbm(vec2(uv.x * 9.0, t * 0.8)));
		vec3 glow = vec3(0.8, 0.1, 0.05) * vein * 0.9 + vec3(1.0, 0.4, 0.12) * ember * 0.7
			+ vec3(0.42, 0.07, 0.06) * smoke * 0.75 + vec3(0.25, 0.05, 0.05) * smoke * smoke;
		float a = smoke * 0.85 * COLOR.a;
		COLOR = vec4(vec3(0.02, 0.015, 0.025) * a + glow * COLOR.a, a);
	}
	"""
	var size := Vector2(120, 96)
	var _mat: ShaderMaterial
	var _light: PointLight2D

	func _ready() -> void:
		var sh := Shader.new()
		sh.code = FOG_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("size", size)
		material = _mat
		# Красный отсвет завесы на земле и стенах проёма
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.width = 128
		tex.height = 128
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.gradient = g
		_light = PointLight2D.new()
		_light.texture = tex
		_light.texture_scale = 2.2
		_light.color = Color(1.0, 0.25, 0.12)
		_light.energy = 0.0
		_light.position = Vector2(0, -20)
		add_child(_light)

	func _process(_d: float) -> void:
		if visible:
			_light.energy = 0.6 * modulate.a * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004))
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), Color.WHITE)





# ───────────────────────── полоса босса ─────────────────────────

## Внизу экрана, над панелью героя: имя, здоровье (красное, с белым
## «следом» отнятого) и концентрация (золотая, растёт от середины к краям;
## пробита — горит ярко и мигает)
class BossBar extends Control:
	const W := 860.0
	const HP_H := 12.0
	const PO_H := 5.0
	const BOTTOM := 158.0
	var boss: Node2D
	var _shown := 0.0
	var _want := 0.0
	var _chip := 1.0
	var _chip_hold := 0.0
	var _last_hp := 1.0
	var _phase_flash := 0.0
	var _font: Font

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var theme := load("res://Main_Menu/theme/MenuTheme.tres") as Theme
		_font = theme.default_font if theme else ThemeDB.fallback_font

	func show_bar() -> void:
		_want = 1.0
		_chip = 1.0
		_last_hp = 1.0

	func hide_bar() -> void:
		_want = 0.0

	func flash_phase(_p: int) -> void:
		_phase_flash = 1.0

	func _process(delta: float) -> void:
		_shown = move_toward(_shown, _want, delta * 1.6)
		_phase_flash = maxf(_phase_flash - delta * 1.2, 0.0)
		if is_instance_valid(boss):
			var hp := clampf(float(boss.get("health")) / maxf(float(boss.get("max_health")), 1.0), 0.0, 1.0)
			if hp < _last_hp:
				_chip_hold = 0.7
			_last_hp = hp
			if _chip_hold > 0.0:
				_chip_hold -= delta
			else:
				_chip = move_toward(_chip, hp, delta * 0.6)
			_chip = maxf(_chip, hp)
		queue_redraw()

	func _draw() -> void:
		if _shown <= 0.001 or not is_instance_valid(boss):
			return
		var vs := get_viewport_rect().size
		var a := _shown
		var x0 := (vs.x - W) * 0.5
		var y := vs.y - BOTTOM
		var hp := _last_hp
		# Имя
		var nm := tr(String(boss.get("boss_name")))
		draw_string(_font, Vector2(x0 + 2, y - 10), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Color(0.92, 0.87, 0.78, a))
		# Здоровье
		draw_rect(Rect2(x0 - 2, y - 2, W + 4, HP_H + 4), Color(0, 0, 0, 0.75 * a))
		draw_rect(Rect2(x0, y, W, HP_H), Color(0.12, 0.05, 0.05, 0.9 * a))
		draw_rect(Rect2(x0, y, W * _chip, HP_H), Color(0.85, 0.78, 0.62, 0.85 * a))
		var red := Color(0.62, 0.08, 0.07).lerp(Color(1.0, 0.35, 0.2), _phase_flash)
		draw_rect(Rect2(x0, y, W * hp, HP_H), Color(red, a))
		draw_rect(Rect2(x0, y, W * hp, 2), Color(1, 0.5, 0.4, 0.35 * a))
		# Концентрация — от середины к краям
		var p := clampf(float(boss.get("posture")) / maxf(float(boss.get("max_posture")), 1.0), 0.0, 1.0)
		var broken: bool = boss.get("is_posture_broken") == true
		var py := y + HP_H + 7.0
		var cx := x0 + W * 0.5
		var pw := W * 0.6
		draw_rect(Rect2(cx - pw * 0.5 - 1, py - 1, pw + 2, PO_H + 2), Color(0, 0, 0, 0.6 * a))
		var gold := Color(0.95, 0.72, 0.3)
		if broken:
			var blink := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
			gold = Color(1.0, 0.9, 0.55) * blink
			p = 1.0
		elif p > 0.75:
			gold = gold.lerp(Color(1.0, 0.45, 0.2), (p - 0.75) * 4.0)
		draw_rect(Rect2(cx - pw * 0.5 * p, py, pw * p, PO_H), Color(gold, a))
		draw_rect(Rect2(cx - 1, py - 2, 2, PO_H + 4), Color(1, 1, 1, 0.5 * a))
