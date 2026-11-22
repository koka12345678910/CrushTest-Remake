extends Node
## enemy_squads.gd — отряды врагов на уровне (узел у корня карты, например
## OrderSquads на reference_map).
##
## Враги в отряде не бродят по карте поодиночке:
##   * hold   — страж: стоит на своей точке лицом туда, откуда придут;
##   * sentry — часовой (обычно стрелок): стоит на посту и смотрит за
##              улицей, видит дальше остальных (vision_range в сцене);
##   * patrol — патруль: идёт строем по маршруту отряда туда-обратно,
##              на концах маршрута стоит и разворачивается.
## Один заметил героя (и видит его, не сквозь стену) или получил удар —
## через долю секунды поднимается весь отряд: стрелки держат дистанцию,
## мечники идут на героя. Ушли слишком далеко от поста или потеряли героя —
## возвращаются на свои места.
##
## Данные расставляет tools/place_order.gd метаданными врагов:
##   squad = "id", squad_role = "hold" | "sentry" | "patrol",
##   facing = Vector2 (куда смотрит на посту),
##   formation = Vector2 (место в строю патруля: x вперёд, y вбок)
## и мета routes у этого узла: {"id": PackedVector2Array(точки маршрута)}.
##
## Ещё здесь ночная подсветка врагов (night_glow): чёрные доспехи Ордена
## ночью сливались с землёй. Слабый холодный свет, который светит только на
## тело врага (свой бит маски света), — силуэт читается, земля вокруг не
## светлеет. Ставится и копиям врагов у клиента в коопе.

const Enemy := preload("res://enemy/enemy.gd")

## Шаг патруля, px/с (мечники идут медленнее обычного шага — дозор)
@export var patrol_speed := 22.0
## Стоянка на концах маршрута, с
@export var patrol_pause := 2.5
## Через сколько секунд тревога доходит до остальных (крик, оглянулись)
@export var alarm_delay := Vector2(0.2, 0.65)
## Ночная подсветка врагов
@export var night_glow := true
@export var glow_energy := 0.9
@export var glow_color := Color(0.62, 0.7, 0.98)
@export var glow_radius := 70.0
## Каким сценам врагов давать подсветку (начало пути к сцене)
@export var glow_scenes: PackedStringArray = ["res://enemy/humans/", "res://enemy/beasts/"]

## Свой бит маски света: подсветка ложится только на тело врага
const GLOW_MASK := 1 << 9
const WORLD_MASK := 1


class SquadData:
	var id := ""
	var members: Array = []
	var route := PackedVector2Array()
	var pos := Vector2.ZERO
	var heading := Vector2.RIGHT
	var idx := 1
	var step := 1
	var pause := 0.0


var stats := {}
var _squads := {}
var _glow_tex: Texture2D
var _glow_t := 0.0
var _night := 1.0


func _ready() -> void:
	# Враги в Objects уже готовы, но позиции/группы надёжнее брать кадром позже
	_setup.call_deferred()


func _setup() -> void:
	var level := get_parent()
	var routes: Dictionary = get_meta("routes", {})
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not level.is_ancestor_of(e) or not e.has_meta("squad"):
			continue
		# Копию врага у клиента ведёт хост — у неё отряда нет
		if e.net_replica:
			continue
		var id := String(e.get_meta("squad"))
		var s: SquadData = _squads.get(id)
		if s == null:
			s = SquadData.new()
			s.id = id
			s.route = routes.get(id, PackedVector2Array())
			_squads[id] = s
		s.members.append(e)
		e.squad = self
		e.on_post = true
		e.post_position = e.global_position
		var f: Vector2 = e.get_meta("facing", Vector2.DOWN)
		e.post_facing = f.normalized() if f.length() > 0.01 else Vector2.DOWN
		e.direction = e.post_facing
		e.post_look = 0.6 if _role(e) == "sentry" else 0.9
	var n_patrol := 0
	for s: SquadData in _squads.values():
		if s.route.size() >= 2:
			s.pos = s.route[0]
			s.heading = (s.route[1] - s.route[0]).normalized()
			n_patrol += 1
	stats = {"squads": _squads.size(), "patrols": n_patrol,
		"members": _squads.values().reduce(func(a, s): return a + s.members.size(), 0)}
	print("EnemySquads: ", stats)


func _role(e: Node) -> String:
	return String(e.get_meta("squad_role", "hold"))


# ------------------------------------------------------------------ тревога

## Поднять отряд врага by на героя hero. need_sight — только если by видит
## героя напрямую (не сквозь стену или дом); удар поднимает всегда
func raise_alarm(by: Node2D, hero: Node2D, need_sight: bool) -> void:
	if not is_instance_valid(by) or not is_instance_valid(hero):
		return
	var s: SquadData = _squads.get(String(by.get_meta("squad", "")))
	if s == null:
		return
	if need_sight and not _sees(by, hero):
		return
	for m in s.members:
		if not is_instance_valid(m) or m.is_dead or m.squad_alert:
			continue
		if m == by:
			_alarm(m, hero)
		else:
			var t := get_tree().create_timer(randf_range(alarm_delay.x, alarm_delay.y), false)
			t.timeout.connect(_alarm.bind(m, hero))


func _alarm(m: Enemy, hero: Node2D) -> void:
	if not is_instance_valid(m) or m.is_dead or m.squad_alert or not is_instance_valid(hero):
		return
	# Спящего (EnemySleep) будим: отряд стоит кучно, сосед рядом с героем
	if m.process_mode == Node.PROCESS_MODE_DISABLED:
		m.process_mode = Node.PROCESS_MODE_INHERIT
	m.player = hero
	m.see_player = true
	m.squad_alert = true
	if m.current_state in [Enemy.State.WANDER, Enemy.State.IDLE]:
		m._change_state(Enemy.State.CHASE)


## Видит ли by героя: луч по коллизии мира. Мелкое (забор, загон, бочки,
## телега — фигура меньше low_obstacle px) взгляд не закрывает, дом и стена —
## закрывают
@export var low_obstacle := 90.0

func _sees(by: Node2D, hero: Node2D) -> bool:
	var space := by.get_world_2d().direct_space_state
	var up := Vector2(0, -12)
	var exclude: Array[RID] = []
	for n in [by, hero]:
		if n is CollisionObject2D:
			exclude.append((n as CollisionObject2D).get_rid())
	var from := by.global_position + up
	var to := hero.global_position + up
	for i in 6:
		var q := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			return true
		if not _low(r["collider"]) and _shape_size(r["collider"], int(r["shape"])) >= low_obstacle:
			return false
		# Низкое препятствие: смотрим поверх него, дальше по лучу
		exclude.append(r["rid"])
	return false


## Пропсы улиц (загоны, телеги, лавки, бочки — узлы с префиксом из
## low_prefixes у тела или его родителя) ниже роста: поверх них видно,
## каким бы широким ни был их забор
@export var low_prefixes: PackedStringArray = ["TownProp_"]

func _low(body: Object) -> bool:
	var n := body as Node
	for i in 2:
		if n == null:
			return false
		for p in low_prefixes:
			if String(n.name).begins_with(p):
				return true
		n = n.get_parent()
	return false


func _shape_size(body: Object, shape_idx: int) -> float:
	var co := body as CollisionObject2D
	if co == null:
		return INF
	var owner_id := co.shape_find_owner(shape_idx)
	if co.shape_owner_get_shape_count(owner_id) == 0:
		return INF
	var sh := co.shape_owner_get_shape(owner_id, 0)
	var xf := co.shape_owner_get_transform(owner_id)
	var size := sh.get_rect().size * xf.get_scale().abs()
	return maxf(size.x, size.y)


# ------------------------------------------------------------------ патруль

func _physics_process(delta: float) -> void:
	for s: SquadData in _squads.values():
		if s.route.size() >= 2:
			_patrol(s, delta)


func _patrol(s: SquadData, delta: float) -> void:
	var walkers: Array = []
	var busy := false
	var asleep := false
	var lagging := false
	for m in s.members:
		if not is_instance_valid(m) or m.is_dead or _role(m) != "patrol":
			continue
		walkers.append(m)
		if m.squad_alert or not (m.current_state in [Enemy.State.WANDER, Enemy.State.IDLE]):
			busy = true
		if not m.can_process():
			asleep = true
		if m.global_position.distance_to(_slot(s, m)) > 46.0:
			lagging = true
	if walkers.is_empty():
		return
	var moving := false
	# Бой, сон или строй отстал — точка патруля ждёт
	if not busy and not asleep:
		var target := s.route[s.idx]
		var to := target - s.pos
		var d := to.length()
		if s.pause > 0.0:
			s.pause -= delta
		elif not lagging:
			var stepd := patrol_speed * delta
			if d <= stepd:
				s.pos = target
				s.pause = patrol_pause
				if s.idx + s.step < 0 or s.idx + s.step >= s.route.size():
					s.step = -s.step
				s.idx += s.step
			else:
				s.pos += to / d * stepd
				moving = true
		# Разворот строя — плавно (на стоянке тоже: оглядываются и
		# поворачиваются к следующему отрезку)
		var want := (s.route[s.idx] - s.pos)
		if want.length() > 1.0:
			var a := s.heading.angle_to(want.normalized())
			s.heading = s.heading.rotated(clampf(a, -1.6 * delta, 1.6 * delta))
	for m in walkers:
		m.post_position = _slot(s, m)
		m.post_facing = s.heading
		m.post_moving = moving


## Место врага в строю: formation.x — вперёд по ходу, .y — вбок
func _slot(s: SquadData, m: Node) -> Vector2:
	var f: Vector2 = m.get_meta("formation", Vector2.ZERO)
	return s.pos + s.heading * f.x + s.heading.orthogonal() * f.y


# ------------------------------------------------------------------ подсветка

func _process(delta: float) -> void:
	if not night_glow:
		return
	_glow_t -= delta
	if _glow_t > 0.0:
		return
	_glow_t = 0.5
	var level := get_parent()
	# Сила — по темноте: днём подсветка не нужна
	var nm := level.get_node_or_null("NightModulate") as CanvasModulate
	if nm:
		var c := nm.color
		_night = clampf(1.0 - (c.r * 0.3 + c.g * 0.59 + c.b * 0.11) * 1.3, 0.0, 1.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not level.is_ancestor_of(e) or not _glow_scene(e):
			continue
		var l := e.get_node_or_null("NightGlow") as PointLight2D
		if l == null:
			l = _add_glow(e)
			if l == null:
				continue
		l.energy = 0.0 if e.is_dead else glow_energy * _night


func _glow_scene(e: Node) -> bool:
	for p in glow_scenes:
		if e.scene_file_path.begins_with(p):
			return true
	return false


func _add_glow(e: Node2D) -> PointLight2D:
	var spr := e.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if spr == null:
		return null
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.gradient = g
		_glow_tex = t
	spr.light_mask |= GLOW_MASK
	var l := PointLight2D.new()
	l.name = "NightGlow"
	l.texture = _glow_tex
	l.texture_scale = glow_radius / 64.0
	l.color = glow_color
	l.energy = 0.0
	l.position = Vector2(0, -14)
	l.range_item_cull_mask = GLOW_MASK
	l.shadow_enabled = false
	e.add_child(l)
	stats["glow"] = int(stats.get("glow", 0)) + 1
	return l
