extends CanvasLayer
## trailer_mode.gd — режим съёмки трейлера (автозагрузка TrailerMode).
## Работает только в отладочной сборке (редактор, debug-экспорт); в релизной
## сборке для игроков его нет.
##
## F9 — включить/выключить режим (и показать подсказку по клавишам).
## Когда режим включён:
##   F1  — интерфейс: всё видно → только полоса босса → ничего (и курсор)
##   F2  — свободная камера: герой стоит, камера летает
##           WASD / стрелки — полёт (Shift — быстрее, Ctrl — медленнее),
##           колесо мыши или + / − — приблизить/отдалить (плавно)
##   + / − без свободной камеры — приблизить/отдалить игровую камеру
##   F3  — замедление времени: 1 → 0.5 → 0.25 → 1
##   F4  — бессмертие (и полные здоровье и выносливость)
##   F6  — запомнить точку А свободной камеры
##   F7  — точка Б и плавный проезд А → Б;  Shift+F7 — повторить проезд
##   [ / ] — длительность проезда (4, 6, 8, 12, 16 с)
##   F8  — перенести героя к следующей точке съёмки (Shift+F8 — к предыдущей)
## Подписи о нажатиях — внизу слева, на секунду; при скрытом интерфейсе (F1)
## их нет вовсе, как и подсказки, — в запись ничего лишнего не попадёт.

const SLOW_STEPS := [1.0, 0.5, 0.25]
const DOLLY_TIMES := [4.0, 6.0, 8.0, 12.0, 16.0]
const CAM_SPEED := 300.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 4.0
## Точки съёмки на карте Хольмвика (reference_map): [название, точка]
const SHOTS := [
	["Нижние ворота", Vector2(1150, 2500)],
	["Горящая нижняя улица", Vector2(-200, 2180)],
	["Дворы нижнего города", Vector2(-1250, 2300)],
	["Внутренние ворота", Vector2(-1900, 1830)],
	["Западный проход", Vector2(-1880, 1320)],
	["Баррикада у ворот", Vector2(-1000, 680)],
	["Площадь ярлов", Vector2(-290, 1180)],
	["Дорога к храму", Vector2(300, 1500)],
	["Врата храма", Vector2(1090, 1340)],
	["Двор храма — бой", Vector2(1090, 1170)],
]
const MAP_SCENE := "res://reference_map_level/reference_map.tscn"
## Слои интерфейса: по скрипту слоя и по имени родителя
const HUD_SCRIPTS := ["hud.gd", "health_stamina_bar.gd", "skill_points_bar.gd", "bonfire_ui.gd"]
const HUD_PARENTS := ["RouteGuide"]
const BOSS_PARENTS := ["BossArena"]

var active := false
var _hud_state := 0          # 0 всё видно, 1 только полоса босса, 2 ничего
var _free := false
var _cam: Camera2D
var _cam_vel := Vector2.ZERO
var _cam_zoom := 1.0
var _cam_zoom_target := 1.0
var _follow_zoom := 1.0
var _base_zoom := Vector2.ZERO
var _slow_i := 0
var _god := false
var _dolly_a := {}
var _dolly_b := {}
var _dolly_t := -1.0
var _dolly_i := 1
var _shot_i := -1
var _applied_scale := 1.0
var _wish_scale := 1.0
var _last_us := 0
var _note: Label
var _help: Label
var _note_t := 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_note = _label(18)
	_note.anchor_top = 1.0
	_note.anchor_bottom = 1.0
	_note.offset_left = 24
	_note.offset_top = -64
	_note.offset_bottom = -24
	_note.visible = false
	add_child(_note)
	_help = _label(17)
	_help.offset_left = 24
	_help.offset_top = 140
	_help.visible = false
	add_child(_help)
	_last_us = Time.get_ticks_usec()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ───────────────────────── клавиши ─────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_F9:
			_set_active(not active)
			_eat()
			return
		if not active:
			return
		var shift: bool = event.shift_pressed
		match k:
			KEY_F1:
				_set_hud((_hud_state + 1) % 3)
			KEY_F2:
				_set_free(not _free)
			KEY_F3:
				_slow_i = (_slow_i + 1) % SLOW_STEPS.size()
				_say("Время ×%s" % str(SLOW_STEPS[_slow_i]))
			KEY_F4:
				_god = not _god
				var h := _hero()
				if h and "is_invulnerable" in h and not _god:
					h.is_invulnerable = false
				_say("Бессмертие: " + ("вкл" if _god else "выкл"))
			KEY_F6:
				_dolly_point(true)
			KEY_F7:
				if shift:
					_dolly_play()
				else:
					_dolly_point(false)
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				_dolly_i = clampi(_dolly_i + (1 if k == KEY_BRACKETRIGHT else -1), 0, DOLLY_TIMES.size() - 1)
				_say("Проезд: %s с" % str(DOLLY_TIMES[_dolly_i]))
			KEY_F8:
				_next_shot(-1 if shift else 1)
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_step(1.12)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_step(1.0 / 1.12)
			_:
				return
		_eat()
	elif active and _free and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_step(1.08)
			_eat()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_step(1.0 / 1.08)
			_eat()


func _eat() -> void:
	get_viewport().set_input_as_handled()


# ───────────────────────── режим ─────────────────────────

func _set_active(on: bool) -> void:
	active = on
	if on:
		_help.text = "РЕЖИМ СЪЁМКИ\n" \
			+ "F1  интерфейс (всё / только босс / ничего)\n" \
			+ "F2  свободная камера: WASD, колесо, Shift/Ctrl\n" \
			+ "+ / −  приблизить / отдалить\n" \
			+ "F3  замедление ×1 / 0.5 / 0.25\n" \
			+ "F4  бессмертие\n" \
			+ "F6  точка А,  F7  точка Б + проезд,  Shift+F7  повтор\n" \
			+ "[ ]  длительность проезда\n" \
			+ "F8  следующая точка съёмки (Shift — предыдущая)\n" \
			+ "F9  выйти из режима"
		_help.visible = true
		get_tree().create_timer(7.0, true, false, true).timeout.connect(func(): _help.visible = false)
		_say("Режим съёмки: вкл")
	else:
		_help.visible = false
		_set_free(false)
		_set_hud(0)
		_slow_i = 0
		if _god:
			_god = false
			var h := _hero()
			if h and "is_invulnerable" in h:
				h.is_invulnerable = false
		_set_follow_zoom(1.0)
		_say("Режим съёмки: выкл")


func _set_hud(state: int) -> void:
	_hud_state = state
	for l in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := l as CanvasLayer
		if cl == self:
			continue
		var scr := cl.get_script() as Script
		var file := scr.resource_path.get_file() if scr else ""
		var parent := String(cl.get_parent().name) if cl.get_parent() else ""
		if file in HUD_SCRIPTS or parent in HUD_PARENTS:
			cl.visible = state == 0
		elif parent in BOSS_PARENTS:
			cl.visible = state < 2
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if state > 0 else Input.MOUSE_MODE_VISIBLE
	# В кадре ничего лишнего: подсказка и подписи режима — только при видимом
	# интерфейсе
	if state > 0:
		_help.visible = false
		_note.visible = false
	_say("Интерфейс: виден")


func _hero() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _hero_cam() -> Camera2D:
	var h := _hero()
	return h.get_node_or_null("Camera2D") as Camera2D if h else null


# ───────────────────────── камера ─────────────────────────

func _set_free(on: bool) -> void:
	var h := _hero()
	if on == _free:
		return
	_free = on
	if on:
		var vp := get_viewport()
		var cur := vp.get_camera_2d()
		_cam = Camera2D.new()
		_cam.name = "TrailerCam"
		_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
		var scene := get_tree().current_scene
		if scene == null:
			_free = false
			return
		scene.add_child(_cam)
		_cam.global_position = cur.get_screen_center_position() if cur else (h.global_position if h else Vector2.ZERO)
		_cam_zoom = cur.zoom.x if cur else 2.0
		_cam_zoom_target = _cam_zoom
		_cam.zoom = Vector2.ONE * _cam_zoom
		_cam.make_current()
		_cam_vel = Vector2.ZERO
		if h and "is_in_shop" in h:
			h.is_in_shop = true
		_say("Свободная камера: вкл")
	else:
		_dolly_t = -1.0
		if is_instance_valid(_cam):
			_cam.queue_free()
		_cam = null
		var hc := _hero_cam()
		if hc:
			hc.make_current()
		if h and "is_in_shop" in h:
			h.is_in_shop = false
		_say("Свободная камера: выкл")


func _zoom_step(f: float) -> void:
	if _free:
		_cam_zoom_target = clampf(_cam_zoom_target * f, ZOOM_MIN, ZOOM_MAX)
		_dolly_t = -1.0
	else:
		_set_follow_zoom(clampf(_follow_zoom * f, 0.4, 2.5))
		_say("Приближение ×%.2f" % _follow_zoom)


## Игровая камера: множитель к её обычному приближению (через Juice — он
## держит базу камеры и накладывает на неё зоны и толчки)
func _set_follow_zoom(z: float) -> void:
	var hc := _hero_cam()
	if hc == null or Juice._cam != hc:
		return
	if _base_zoom == Vector2.ZERO:
		_base_zoom = Juice._cam_base_zoom
	_follow_zoom = z
	Juice._cam_base_zoom = _base_zoom * z
	Juice._cam_dirty = true
	if z == 1.0:
		_base_zoom = Vector2.ZERO


func _dolly_point(a: bool) -> void:
	if not _free:
		_set_free(true)
	var p := {"pos": _cam.global_position, "zoom": _cam_zoom}
	if a:
		_dolly_a = p
		_say("Точка А запомнена")
	else:
		_dolly_b = p
		if _dolly_a.is_empty():
			_say("Сначала точка А (F6)")
			return
		_dolly_play()


func _dolly_play() -> void:
	if _dolly_a.is_empty() or _dolly_b.is_empty():
		_say("Нужны точки А (F6) и Б (F7)")
		return
	if not _free:
		_set_free(true)
	_dolly_t = 0.0
	_cam.global_position = _dolly_a["pos"]
	_cam_zoom = _dolly_a["zoom"]
	_cam_zoom_target = _cam_zoom
	_say("Проезд %s с" % str(DOLLY_TIMES[_dolly_i]))


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if _note_t > 0.0:
		_note_t -= dt
		if _note_t <= 0.0:
			_note.visible = false
	_apply_time()
	if not active:
		return
	if _god:
		_keep_alive()
	if _free and is_instance_valid(_cam):
		_fly(dt)


## Свободная камера по реальному времени (замедление на неё не влияет)
func _fly(dt: float) -> void:
	if _dolly_t >= 0.0:
		var dur: float = DOLLY_TIMES[_dolly_i]
		_dolly_t += dt
		var t := smoothstep(0.0, 1.0, clampf(_dolly_t / dur, 0.0, 1.0))
		_cam.global_position = (_dolly_a["pos"] as Vector2).lerp(_dolly_b["pos"], t)
		_cam_zoom = lerpf(_dolly_a["zoom"], _dolly_b["zoom"], t)
		_cam_zoom_target = _cam_zoom
		_cam.zoom = Vector2.ONE * _cam_zoom
		if _dolly_t >= dur:
			_dolly_t = -1.0
		return
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	var speed := CAM_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 3.0
	elif Input.is_key_pressed(KEY_CTRL):
		speed *= 0.3
	# Плавный разгон и торможение — проезд без рывков
	var want := dir * speed / _cam_zoom
	_cam_vel = _cam_vel.lerp(want, 1.0 - exp(-4.0 * dt))
	_cam.global_position += _cam_vel * dt
	_cam_zoom = lerpf(_cam_zoom, _cam_zoom_target, 1.0 - exp(-5.0 * dt))
	_cam.zoom = Vector2.ONE * _cam_zoom


## Замедление: поверх того, что просит игра (стоп-кадры, Juice.slow), —
## множитель. Кто-то сменил Engine.time_scale — это его желание, умножаем
func _apply_time() -> void:
	var f: float = SLOW_STEPS[_slow_i] if active else 1.0
	if not is_equal_approx(Engine.time_scale, _applied_scale):
		_wish_scale = Engine.time_scale
	var s := _wish_scale * f
	if not is_equal_approx(Engine.time_scale, s):
		Engine.time_scale = s
	_applied_scale = Engine.time_scale


func _keep_alive() -> void:
	var h := _hero()
	if h == null:
		return
	if "is_invulnerable" in h:
		h.is_invulnerable = true
	var hb = h.get("health_bar")
	if hb:
		if hb.has_method("heal") and "max_hp" in hb:
			hb.heal(hb.max_hp)
			if "health" in h and "current_hp" in hb:
				h.health = hb.current_hp
		if "current_stamina" in hb and "max_stamina" in hb:
			hb.current_stamina = hb.max_stamina


# ───────────────────────── точки съёмки ─────────────────────────

func _next_shot(step: int) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != MAP_SCENE:
		_say("Точки съёмки — только на карте Хольмвика")
		return
	var h := _hero()
	if h == null:
		return
	_shot_i = wrapi(_shot_i + step, 0, SHOTS.size())
	var p: Vector2 = SHOTS[_shot_i][1]
	var nav := h.get_world_2d().navigation_map
	var q := NavigationServer2D.map_get_closest_point(nav, p)
	if q != Vector2.ZERO:
		p = q
	h.global_position = p
	if "velocity" in h:
		h.velocity = Vector2.ZERO
	if _free and is_instance_valid(_cam):
		_cam.global_position = p
		_dolly_t = -1.0
	_say("%d. %s" % [_shot_i + 1, SHOTS[_shot_i][0]])


func _say(text: String) -> void:
	if _hud_state > 0 and active:
		return
	_note.text = text
	_note.visible = true
	_note_t = 1.4
