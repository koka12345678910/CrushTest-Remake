extends RefCounted
## mage_reactions.gd — стихийные реакции мага: огонь и лёд не просто бьют, а
## складываются друг с другом. Только статические функции:
##   const Reactions := preload("res://Player_scene/mage_reactions.gd")
##
## Каждый удар заклинания идёт через strike(): маг на время удара помечается
## стихией (meta "hit_element"), враг зовёт mage.on_weapon_hit (enemy.gd::
## _notify_weapon_hit) — там маг и решает, что сработало:
##   огонь по врагу  -> ОПАЛ   (метка scorched_until, голубые угли на враге)
##   лёд по опалённому, огонь по охлаждённому -> ПАР: взрыв пара — урон,
##                     удар по стойкости и отброс вокруг; обе метки сгорают
##   импульс по опалённому -> ВСПЫШКА: пламя срывается с врага волной —
##                     ранит и поджигает соседей (огонь перекидывается)
##   убит охлаждённым -> РАСКОЛ: враг лопается ледяными осколками, они ранят и
##                     морозят соседей; добитый охлаждённый сосед лопается тоже
##                     (цепочка, не глубже MAX_CHAIN)
## Над врагом всплывает название реакции.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")
const Clean := preload("res://UI/clean_hud.gd")

const SCORCH_SEC := 4.0
## Последняя надпись каждой реакции: [мс, точка] — чтобы не сыпать их кучей
static var _last_popup := {}
const MAX_CHAIN := 5
## Цвета надписей реакций
const COL_STEAM := Color(0.92, 0.95, 1.0)
const COL_SHATTER := Color(0.62, 0.9, 1.0)
const COL_FLARE := Color(0.45, 0.68, 1.0)
const COL_EXECUTE := Color(0.95, 0.78, 0.4)


## Удар заклинания стихией element ("fire", "ice", "force", "steam",
## "shatter", "flare"). unblockable — мимо блока (у разбиваемых предметов
## такого параметра нет)
static func strike(caster: Node2D, e: Node2D, dmg: int, element: String, unblockable := false) -> void:
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	var had := is_instance_valid(caster)
	if had:
		caster.set_meta("hit_element", element)
	if unblockable and e.has_method("execute_kill"):
		e.take_damage(dmg, caster, true)
	else:
		e.take_damage(dmg, caster)
	if had and is_instance_valid(caster):
		caster.set_meta("hit_element", "")


# ===================== ОПАЛ =====================

static func is_scorched(e: Node) -> bool:
	return is_instance_valid(e) and Time.get_ticks_msec() / 1000.0 < float(e.get_meta("scorched_until", 0.0))


## Враг опалён: метка и голубые угли, поднимающиеся с него, пока не истечёт
static func scorch(e: Node2D, sec := SCORCH_SEC) -> void:
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	var until := Time.get_ticks_msec() / 1000.0 + sec
	e.set_meta("scorched_until", maxf(until, float(e.get_meta("scorched_until", 0.0))))
	var fx := e.get_node_or_null("ScorchFx") as Node2D
	if fx == null:
		fx = Node2D.new()
		fx.name = "ScorchFx"
		fx.z_index = 1
		fx.position = Vector2(0, -4)
		e.add_child(fx)
		var p := GPUParticles2D.new()
		p.amount = 10
		p.lifetime = 0.8
		p.local_coords = false
		p.texture = MageFx.dot()
		p.visibility_rect = MageFx.VIS_RECT
		p.material = MageFx.add_material()
		var pm := ParticleProcessMaterial.new()
		pm.particle_flag_disable_z = true
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(8, 12, 0)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 30.0
		pm.initial_velocity_min = 14.0
		pm.initial_velocity_max = 34.0
		pm.gravity = Vector3(0, -20, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		pm.color_ramp = MageFx.ramp([Color(MageFx.CORE, 1.0), Color(MageFx.MID, 0.85), Color(MageFx.EDGE, 0.0)], [0.0, 0.35, 1.0])
		p.process_material = pm
		fx.add_child(p)
	var wr: WeakRef = weakref(e)
	e.get_tree().create_timer(sec + 0.05).timeout.connect(func():
		var en := wr.get_ref() as Node2D
		if en == null or is_scorched(en):
			return
		var f := en.get_node_or_null("ScorchFx")
		if f:
			f.queue_free())


## Снять обе метки (реакция их «сожгла»): оттенок, угли, снежинки. Короткая
## блокировка не даёт тому же удару сразу заново охладить врага
static func clear_status(e: Node2D) -> void:
	if not is_instance_valid(e):
		return
	e.set_meta("scorched_until", 0.0)
	e.set_meta("chilled_until", 0.0)
	e.set_meta("status_lock_until", Time.get_ticks_msec() / 1000.0 + 0.3)
	var sp := e.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sp:
		sp.self_modulate = Color.WHITE
	for n in ["ScorchFx", "ChillFx"]:
		var f := e.get_node_or_null(n)
		if f:
			f.queue_free()


static func status_locked(e: Node) -> bool:
	return is_instance_valid(e) and Time.get_ticks_msec() / 1000.0 < float(e.get_meta("status_lock_until", 0.0))


static func _neighbors(tree: SceneTree, center: Vector2, radius: float, except: Node) -> Array:
	var out := []
	for n in IceFx.targets(tree):
		if n == except:
			continue
		if IceFx.ground_dist(center, IceFx.feet(n), 0.7) <= radius:
			out.append(n)
	return out


# ===================== ПАР =====================

## Лёд встретил огонь на враге: взрыв пара. Целью — урон dmg, соседям в
## радиусе — 1, всем — удар по стойкости и отброс. Срабатывает на миг позже
## удара (вне take_damage, что его вызвал)
static func steam(caster: Node2D, e: Node2D, dmg := 2, radius := 62.0) -> void:
	clear_status(e)
	var tree := e.get_tree()
	var at := IceFx.feet(e)
	popup(tree, e.global_position + Vector2(0, -34), "ПАР", COL_STEAM)
	var wr: WeakRef = weakref(e)
	tree.create_timer(0.06).timeout.connect(func():
		var en: Node2D = wr.get_ref()
		var h := MageFx.holder(tree, at + Vector2(0, -14), 2.0, 12)
		MageFx.flash(h, 70.0, 0.16, Color(1.0, 1.0, 1.0))
		MageFx.light_pulse(h, 110.0, 1.4, 0.4, Color(0.85, 0.92, 1.0))
		# Пар: плотные белые клубы, поднимаются и расплываются
		IceFx.mist(h, 14, 18.0, 52.0, 1.5, 0.55)
		_droplets(h)
		MageFx.sparks(h, 10, 200.0, 0.3)
		SoundBank.play_at(tree, "execution_wave", at, -9.0, 1.5)
		if is_instance_valid(caster) and caster.has_method("shake_camera"):
			caster.shake_camera(4.0, 0.2)
		var victims := _neighbors(tree, at, radius, en)
		if is_instance_valid(en) and en.get("is_dead") != true:
			victims.push_front(en)
		for v in victims:
			if not is_instance_valid(v) or v.get("is_dead") == true:
				continue
			strike(caster, v, dmg if v == en else 1, "steam")
			if is_instance_valid(v) and v.get("is_dead") != true:
				if v.has_method("take_posture_damage"):
					v.take_posture_damage(28.0)
				if "knockback_velocity" in v:
					var to: Vector2 = IceFx.feet(v) - at
					v.knockback_velocity = (to.normalized() if to.length() > 1.0 else Vector2.DOWN) * 230.0)


## Брызги кипятка: светлые капли разлетаются и падают
static func _droplets(parent: Node) -> void:
	MageFx.burst(parent, 18, 0.55, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 80.0
		pm.initial_velocity_min = 70.0
		pm.initial_velocity_max = 170.0
		pm.gravity = Vector3(0, 380, 0)
		pm.scale_min = 0.4
		pm.scale_max = 0.8
		pm.color_ramp = MageFx.ramp([Color(1, 1, 1, 1.0), Color(0.8, 0.9, 1.0, 0.8), Color(0.6, 0.75, 0.9, 0.0)]))


# ===================== ВСПЫШКА =====================

## Импульс задел опалённого: пламя срывается с него кольцом — соседям урон,
## отброс и опал (огонь перекидывается дальше)
static func flare(caster: Node2D, e: Node2D, radius := 74.0) -> void:
	clear_status(e)
	var tree := e.get_tree()
	var at := IceFx.feet(e)
	popup(tree, e.global_position + Vector2(0, -34), "ВСПЫШКА", COL_FLARE)
	var wr: WeakRef = weakref(e)
	tree.create_timer(0.05).timeout.connect(func():
		var en: Node2D = wr.get_ref()
		var h := MageFx.holder(tree, at + Vector2(0, -12), 1.6, 12)
		MageFx.flash(h, 64.0, 0.14, MageFx.MID)
		MageFx.light_pulse(h, 120.0, 1.8, 0.45, MageFx.MID)
		MageFx.sparks(h, 22, 260.0, 0.4)
		MageFx.embers(h, 18, 16.0, 1.0)
		MageFx.smoke(h, 6, 12.0, 30.0, 0.9)
		if is_instance_valid(caster) and caster.has_method("shake_camera"):
			caster.shake_camera(3.5, 0.18)
		for v in _neighbors(tree, at, radius, en):
			strike(caster, v, 1, "flare")
			if is_instance_valid(v) and v.get("is_dead") != true:
				scorch(v)
				if "knockback_velocity" in v:
					var to: Vector2 = IceFx.feet(v) - at
					v.knockback_velocity = (to.normalized() if to.length() > 1.0 else Vector2.DOWN) * 200.0)


# ===================== РАСКОЛ =====================

## Охлаждённый враг погиб — лопается льдом. depth — звено цепочки (0 — первый)
static func shatter(caster: Node2D, e: Node2D, depth := 0, radius := 66.0) -> void:
	var tree := e.get_tree()
	var at := IceFx.feet(e)
	clear_status(e)
	popup(tree, e.global_position + Vector2(0, -34), "РАСКОЛ" if depth == 0 else "РАСКОЛ ×%d" % (depth + 1), COL_SHATTER)
	# Тело «застывает» на миг белым льдом и лопается
	var sp := e.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sp:
		sp.self_modulate = Color(1.6, 1.9, 2.2)
	var h := MageFx.holder(tree, at + Vector2(0, -14), 1.6, 12)
	MageFx.flash(h, 56.0, 0.14, IceFx.CORE)
	MageFx.light_pulse(h, 100.0, 1.5, 0.4, IceFx.MID)
	IceFx.shards(h, 34, 280.0, 0.65, Vector2.ZERO, 180.0, 260.0)
	IceFx.mist(h, 6, 10.0, 30.0, 1.0, 0.3)
	for i in 5:
		var a := TAU * (i + randf_range(-0.2, 0.2)) / 5.0
		IceFx.spike(tree, at + Vector2(cos(a), sin(a) * 0.62) * randf_range(8.0, 16.0),
				randf_range(12.0, 20.0), randf_range(5.0, 8.0), 0.0, 0.25, cos(a) * 0.5)
	IceFx.frost_decal(tree, at, 40.0, 1.8, 0.5)
	SoundBank.play_at(tree, "trap_snap", at, -5.0, 1.5 + 0.1 * depth)
	if is_instance_valid(caster) and caster.has_method("shake_camera"):
		caster.shake_camera(3.0 + depth, 0.16)
	# Осколки долетают до соседей чуть позже — цепочка читается по шагам
	var wr: WeakRef = weakref(e)
	tree.create_timer(0.09).timeout.connect(func():
		var en: Node2D = wr.get_ref()
		for v in _neighbors(tree, at, radius, en):
			if not is_instance_valid(v) or v.get("is_dead") == true:
				continue
			if is_instance_valid(caster):
				caster.set_meta("shatter_depth", depth + 1)
			strike(caster, v, 1, "shatter")
			if is_instance_valid(caster):
				caster.set_meta("shatter_depth", 0)
			if is_instance_valid(v) and v.get("is_dead") != true:
				IceFx.chill(v, 45.0, 2.0)
				if "knockback_velocity" in v:
					var to: Vector2 = IceFx.feet(v) - at
					v.knockback_velocity = (to.normalized() if to.length() > 1.0 else Vector2.DOWN) * 150.0)


# ===================== НАДПИСЬ =====================

## Название реакции над врагом: всплывает, чуть увеличивается и тает
static func popup(tree: SceneTree, at: Vector2, text: String, col: Color) -> void:
	var root := tree.current_scene
	if root == null:
		return
	# Цепочка раскола даёт по надписи на каждого — рядом и почти разом они
	# сливались в кашу. Та же реакция рядом в пределах 0.35 с — одна надпись
	var kind := text.split(" ×")[0]
	var now := Time.get_ticks_msec()
	var last: Array = _last_popup.get(kind, [-100000, Vector2.ZERO])
	if now - int(last[0]) < 350 and (last[1] as Vector2).distance_to(at) < 120.0:
		return
	_last_popup[kind] = [now, at]
	var l := Label.new()
	l.text = tr_text(text)
	l.add_theme_font_override("font", Clean.font())
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 34)
	l.pivot_offset = l.size * 0.5
	l.z_as_relative = false
	l.z_index = 30
	l.scale = Vector2.ONE * 0.35
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(l)
	l.global_position = at - l.size * 0.5 + Vector2(randf_range(-6, 6), 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE * 0.5, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "global_position:y", l.global_position.y - 20.0, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	t.set_parallel(false)
	t.tween_callback(l.queue_free)


## Перевод надписи (Label сам переводит только text из сцены — тут
## шаблоны с числом, поэтому руками)
static func tr_text(s: String) -> String:
	var parts := s.split(" ×")
	var head := TranslationServer.translate(parts[0])
	return head if parts.size() == 1 else head + " ×" + parts[1]
