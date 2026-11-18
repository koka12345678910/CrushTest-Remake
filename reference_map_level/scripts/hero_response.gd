extends Node2D
## hero_response.gd — земля отвечает на шаги героя (reference_map).
##
## Что под ногами — по маскам карты (те же, что рисуют землю):
##   wood  — мосты, причал, настилы (слой Bridges и спрайты PortDecks,
##           BridgeDecks, SouthBridges);
##   stone — брусчатка (terrain/cobble_map.res, R), двор форта (FortFloor);
##   mire  — болото (terrain/zones.res, R): шлепки, круги по воде, следы;
##   mud   — грязь лагеря (terrain/camp_ground_mask.res, R): глубокие следы;
##   dirt  — тропы (terrain/paths.res, R/B): следы и пыль из-под ног;
##   grass — всё остальное.
## Звук шага берёт отсюда же Levels/sound_bank.gd (surface_at через группу
## "surface_provider", её выставляет immersion.gd).
## Следы и круги рисуются этим узлом под объектами карты, пыль — частицами.

const WORLD := Rect2(-3520, -704, 9408, 5120)
const TERRAIN := "res://reference_map_level/textures/terrain/"
## Шаг героя для следов, мировые px
const STEP := 26.0
const MAX_PRINTS := 220

var _paths: Image
var _zones: Image
var _cobble: Image
var _camp_mud: Image
var _camp_origin := Vector2.ZERO
var _camp_px := 4.0
var _bridges: TileMapLayer
var _wood: Array[Sprite2D] = []
var _stone: Array[Sprite2D] = []

## {"p", "dir", "t", "kind"}
var _prints: Array[Dictionary] = []
## {"p", "t"}
var _ripples: Array[Dictionary] = []
## нода героя -> {"last", "acc", "left"}
var _walkers := {}
var _dust: Array[CPUParticles2D] = []
var _dust_i := 0
var _redraw := 0.0
## Второй экземпляр может только рисовать следы ядра (core) — внутри лагеря:
## его земля лежит в Objects, и следы под Objects были бы под ней
var core: Node = null
## Рисовать только следы внутри clip (если задан) и не рисовать внутри skip
var clip := Rect2()
var skip := Rect2()


func setup(map: Node) -> void:
	_paths = _img(TERRAIN + "paths.res")
	_zones = _img(TERRAIN + "zones.res")
	_cobble = _img(TERRAIN + "cobble_map.res")
	# Маска грязи — в координатах лагеря: без лагеря (убран с карты) её нет
	var camp := map.get_node_or_null("Objects/RuinedCamp") as Node2D
	if camp:
		_camp_mud = _img(TERRAIN + "camp_ground_mask.res")
		_camp_origin = camp.global_position
		var mg := camp.get_node_or_null("MudGround") as Sprite2D
		if mg:
			_camp_px = mg.scale.x
	_bridges = map.get_node_or_null("Bridges") as TileMapLayer
	for path in ["PortDecks", "BridgeDecks", "SouthBridges"]:
		var n := map.get_node_or_null(path)
		if n:
			for c in n.get_children():
				if c is Sprite2D:
					_wood.append(c)
	var ff := map.get_node_or_null("FortFloor") as Sprite2D
	if ff:
		_stone.append(ff)
	for i in 6:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 7
		p.lifetime = 0.9
		p.explosiveness = 0.9
		p.direction = Vector2(0, -1)
		p.spread = 70.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 16.0
		p.gravity = Vector2(4.0, -3.0)
		p.damping_min = 6.0
		p.damping_max = 10.0
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.4
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1.25, 1.15, 1.0, 0.35), Color(1.25, 1.15, 1.0, 0.0)])
		p.color_ramp = g
		p.z_index = 1
		add_child(p)
		_dust.append(p)


func _img(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	var i := t.get_image()
	if i and i.is_compressed():
		i.decompress()
	return i


func _sample(img: Image, at: Vector2, rect: Rect2) -> Color:
	if img == null:
		return Color(0, 0, 0, 0)
	var uv := (at - rect.position) / rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Color(0, 0, 0, 0)
	return img.get_pixel(int(uv.x * img.get_width()), int(uv.y * img.get_height()))


func _in_sprite(s: Sprite2D, at: Vector2) -> bool:
	if not is_instance_valid(s) or not s.visible:
		return false
	return s.get_rect().has_point(s.to_local(at))


## Что под ногами (подробно, для следов)
func ground_at(at: Vector2) -> String:
	if _bridges and _bridges.get_cell_source_id(_bridges.local_to_map(_bridges.to_local(at))) != -1:
		return "wood"
	for s in _wood:
		if _in_sprite(s, at):
			return "wood"
	for s in _stone:
		if _in_sprite(s, at):
			return "stone"
	if _sample(_cobble, at, WORLD).r > 0.5:
		return "stone"
	if _sample(_zones, at, WORLD).r > 0.5:
		return "mire"
	if _camp_mud:
		var cr := Rect2(_camp_origin, Vector2(_camp_mud.get_size()) * _camp_px)
		if _sample(_camp_mud, at, cr).r > 0.5:
			return "mud"
	var pc := _sample(_paths, at, WORLD)
	if pc.r > 0.45 or pc.b > 0.45:
		return "dirt"
	return "grass"


## Для звука шага (sound_bank.gd): "wood", "stone", "water" или "" — обычный
func surface_at(at: Vector2) -> String:
	match ground_at(at):
		"wood":
			return "wood"
		"stone":
			return "stone"
		"mire":
			return "water"
	return ""


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if core != null:
		_redraw -= delta
		if not core.get("_ripples").is_empty() or _redraw <= 0.0:
			_redraw = 0.3
			queue_redraw()
		return
	for h in get_tree().get_nodes_in_group("player"):
		if not h is Node2D or not is_instance_valid(h):
			continue
		var pos: Vector2 = (h as Node2D).global_position
		if not _walkers.has(h):
			_walkers[h] = {"last": pos, "acc": 0.0, "left": false}
			continue
		var w: Dictionary = _walkers[h]
		var mv: Vector2 = pos - w["last"]
		w["last"] = pos
		if mv.length() > 60.0:
			# Телепорт/рывок — не шаги
			w["acc"] = 0.0
			continue
		w["acc"] += mv.length()
		if w["acc"] >= STEP and mv.length() > 0.01:
			w["acc"] = 0.0
			w["left"] = not w["left"]
			_step(pos, mv.normalized(), w["left"], mv.length() / maxf(delta, 0.001), now)
	# Старые следы и круги уходят; перерисовка не каждый кадр
	_redraw -= delta
	var busy := not _ripples.is_empty()
	if busy or _redraw <= 0.0:
		_redraw = 0.3
		_expire(now)
		queue_redraw()


func _step(pos: Vector2, dir: Vector2, left: bool, speed: float, now: float) -> void:
	var kind := ground_at(pos)
	match kind:
		"mire":
			_ripples.append({"p": pos + Vector2(0, 2), "t": now})
			_add_print(pos, dir, left, now, "mire")
		"mud":
			_add_print(pos, dir, left, now, "mud")
		"dirt":
			_add_print(pos, dir, left, now, "dirt")
			if speed > 90.0 and randf() < 0.55:
				_puff(pos)


func _add_print(pos: Vector2, dir: Vector2, left: bool, now: float, kind: String) -> void:
	var side := Vector2(-dir.y, dir.x) * (3.0 if left else -3.0)
	_prints.append({"p": pos + side + Vector2(0, 1), "dir": dir, "t": now, "kind": kind})
	if _prints.size() > MAX_PRINTS:
		_prints.remove_at(0)


func _puff(pos: Vector2) -> void:
	var p := _dust[_dust_i]
	_dust_i = (_dust_i + 1) % _dust.size()
	p.global_position = pos + Vector2(0, 1)
	p.restart()


## Сколько живёт след (с)
func _life(kind: String) -> float:
	match kind:
		"mud":
			return 70.0
		"mire":
			return 25.0
	return 40.0


func _expire(now: float) -> void:
	var i := 0
	while i < _prints.size() and now - float(_prints[i]["t"]) > _life(_prints[i]["kind"]):
		i += 1
	if i > 0:
		_prints = _prints.slice(i)
	for j in range(_ripples.size() - 1, -1, -1):
		if now - float(_ripples[j]["t"]) > 1.2:
			_ripples.remove_at(j)


func _visible(p: Vector2) -> bool:
	if clip.has_area() and not clip.has_point(p):
		return false
	return not (skip.has_area() and skip.has_point(p))


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var src: Node = core if core != null else self
	var o := global_position
	for f in src.get("_prints"):
		if not _visible(f["p"]):
			continue
		var age: float = now - float(f["t"])
		var life := _life(f["kind"])
		var k := clampf(1.0 - age / life, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var base := 0.0
		var col := Color(0.09, 0.06, 0.04)
		match f["kind"]:
			"mud":
				base = 0.7
			"mire":
				base = 0.5
				col = Color(0.05, 0.06, 0.05)
			_:
				base = 0.4
				col = Color(0.14, 0.1, 0.07)
		col.a = base * k
		var dir: Vector2 = f["dir"]
		var p: Vector2 = f["p"] - o
		# Земля в ракурсе 3/4 сплюснута по вертикали
		draw_set_transform_matrix(Transform2D(0.0, p) * Transform2D(0.0, Vector2(1.0, 0.7), 0.0, Vector2.ZERO) * Transform2D(dir.angle(), Vector2.ZERO))
		# Валик выдавленной земли (светлее), потом подошва и каблук
		if f["kind"] != "dirt":
			var rim := Color(1.0, 0.85, 0.7, col.a * 0.35)
			_ellipse(Vector2(2.4, 0.5), Vector2(4.6, 2.6), rim)
			_ellipse(Vector2(-3.0, 0.5), Vector2(2.4, 2.2), rim)
		_ellipse(Vector2(2.2, 0), Vector2(4.0, 2.1), col)
		_ellipse(Vector2(-3.2, 0), Vector2(2.0, 1.9), col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for r in src.get("_ripples"):
		if not _visible(r["p"]):
			continue
		var age: float = now - float(r["t"])
		for j in 2:
			var a := age - j * 0.22
			if a <= 0.0:
				continue
			var x := clampf(a / 1.0, 0.0, 1.0)
			var rad := 3.0 + 15.0 * (1.0 - pow(1.0 - x, 2.0))
			var col := Color(0.85, 0.9, 1.0, 0.28 * (1.0 - x))
			draw_set_transform(r["p"] - o, 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 28, col, 1.2, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
