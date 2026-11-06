extends CanvasLayer
## SceneLoader.gd (автозагрузка)
## Плавный переход между сценами через экран загрузки.
##
## Раньше меню звало change_scene_to_file() — это синхронная загрузка:
## уровень со всеми текстурами грузится прямо в главном потоке, картинка
## замирает на секунду-другую, а потом игра резко "выпрыгивает". Теперь:
##   1. текущая сцена уходит в чёрное, звук сцены плавно гаснет;
##   2. на чёрном проявляется экран загрузки, уровень грузится в фоновом
##      потоке (load_threaded_request) — экран всё это время живой;
##   3. экран гаснет, сцена меняется ПОД чёрным, пара кадров на то, чтобы
##      отработали _ready() и скомпилировались шейдеры (самый заметный
##      рывок первого кадра) — игрок этого не видит;
##   4. новая сцена медленно проявляется из чёрного.
##
## Использование: SceneLoader.change_scene("res://Levels/level_01.tscn")

signal scene_changed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const LOGO_SHADER := preload("res://Main_Menu/assets/shaders/logo_ember.gdshader")
const LOGO_SHEET := preload("res://Main_Menu/TLO_anim.png")
const SpriteSheetAnimationScript := preload("res://Main_Menu/scripts/SpriteSheetAnimation.gd")

# Тайминги перехода (секунды)
const FADE_OUT_TIME := 0.8       # уходящая сцена гаснет в чёрное
const CONTENT_FADE_TIME := 0.5   # экран загрузки появляется/исчезает
const REVEAL_TIME := 1.1         # новая сцена проявляется из чёрного
# Даже если уровень уже в кэше и грузится мгновенно, экран не должен
# мелькнуть на долю секунды — это выглядит как глюк, а не как загрузка
const MIN_SHOW_TIME := 1.8
# Кадры под чёрным после смены сцены — там _ready() уровня и компиляция
# шейдеров, из-за которых и был "резкий" старт
const SETTLE_FRAMES := 4
# Полоса догоняет реальный прогресс плавно, не скачками (доля в секунду)
const BAR_SPEED := 0.9

const BG_COLOR := Color(0.008, 0.008, 0.008)
const GOLD := Style.GOLD
const GOLD_BRIGHT := Style.GOLD_HI
const TEXT_COLOR := Style.TEXT
const TEXT_DIM_COLOR := Style.TEXT_DIM

const TIPS := [
	"Четвёртый удар серии — с разворота: он задевает всех врагов вокруг.",
	"Вовремя парированный удар открывает врага для ответа.",
	"Перекат проносит сквозь врагов — но не сквозь стены.",
	"Отдай кровь Руне Жертвы — и боги забудут, что твои силы на перезарядке.",
	"Благословение Бальдра может однажды спасти от смертельного удара.",
	"Под взором Одина время замедляется — и отмеченные уже не встают.",
	"Кровь Фенрира делает тебя несокрушимым и злее с каждой секундой.",
	"Выносливость — это жизнь. Выдохшийся воин — мёртвый воин.",
	"Заметивший тебя враг не забудет. Бей первым.",
	"У костра можно отдохнуть: здоровье вернётся, но враги воскреснут.",
]

var _busy := false
var _black: ColorRect
var _content: Control
var _logo: TextureRect
var _bar_fill: ColorRect
var _bar_tip: ColorRect
var _loading_label: Label
var _tip_label: Label
var _time := 0.0
var _shown_progress := 0.0
var _target_progress := 0.0


func _ready() -> void:
	# Поверх всего: HUD, меню, панели настроек
	layer = 128
	# Экран должен жить и тогда, когда дерево на паузе (например, выход
	# в меню из паузы)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_busy() -> bool:
	return _busy


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	var tree := get_tree()
	# Пока идёт переход, клики и клавиши не должны доходить до меню —
	# иначе можно успеть нажать вторую кнопку под затемнением
	tree.root.gui_disable_input = true

	visible = true
	_black.modulate.a = 0.0
	_content.modulate.a = 0.0
	_fade_scene_audio(tree.current_scene, FADE_OUT_TIME)
	await _fade(_black, 1.0, FADE_OUT_TIME, Tween.EASE_IN)

	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_error("SceneLoader: не удалось начать загрузку %s (%s)" % [path, error_string(err)])
		tree.change_scene_to_file(path)
		await _finish(tree)
		return

	_tip_label.text = TIPS[randi() % TIPS.size()]
	_shown_progress = 0.0
	_target_progress = 0.0
	_update_bar()
	var started := Time.get_ticks_msec()
	await _fade(_content, 1.0, CONTENT_FADE_TIME, Tween.EASE_OUT)

	# Ждём фоновый поток. Реальный прогресс Godot отдаёт рывками, поэтому
	# полоса только "целится" в него, а сама едет плавно в _process()
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_error("SceneLoader: загрузка %s провалилась" % path)
			break
		if not progress.is_empty():
			_target_progress = maxf(_target_progress, float(progress[0]))
		await tree.process_frame

	_target_progress = 1.0
	while _shown_progress < 1.0 or Time.get_ticks_msec() - started < MIN_SHOW_TIME * 1000.0:
		await tree.process_frame

	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	await _fade(_content, 0.0, CONTENT_FADE_TIME, Tween.EASE_IN)

	if packed:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(path)
	await _finish(tree)


## Сцена уже сменена, экран полностью чёрный — даём ей "продышаться"
## несколько кадров и проявляем
func _finish(tree: SceneTree) -> void:
	for i in SETTLE_FRAMES:
		await tree.process_frame
	tree.root.gui_disable_input = false
	scene_changed.emit()
	await _fade(_black, 0.0, REVEAL_TIME, Tween.EASE_OUT)
	visible = false
	_busy = false


func _fade(node: CanvasItem, to: float, duration: float, ease_type: Tween.EaseType) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", to, duration)\
		.set_ease(ease_type).set_trans(Tween.TRANS_SINE)
	await t.finished


## Музыка меню не должна обрываться на полуслове при смене сцены — гасим
## все плееры уходящей сцены вместе с картинкой
func _fade_scene_audio(scene: Node, duration: float) -> void:
	if scene == null:
		return
	var t := create_tween().set_parallel(true)
	var any := false
	for node in scene.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			if node.playing:
				t.tween_property(node, "volume_db", -60.0, duration)\
					.set_ease(Tween.EASE_IN)
				any = true
	if not any:
		t.kill()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_shown_progress = move_toward(_shown_progress, _target_progress, BAR_SPEED * delta)
	_update_bar()
	# Лого «дышит» жаром в шейдере (logo_ember), прозрачность не мигает
	_loading_label.modulate.a = 0.45 + 0.35 * (0.5 + 0.5 * sin(_time * 2.4))
	# Ромбик на конце полосы мерцает, как уголёк
	_bar_tip.modulate.a = 0.7 + 0.3 * sin(_time * 7.0)


func _update_bar() -> void:
	var w: float = (_bar_fill.get_parent() as Control).size.x
	_bar_fill.size.x = w * _shown_progress
	_bar_tip.position.x = w * _shown_progress - _bar_tip.size.x / 2.0


# ── Вёрстка ───────────────────────────────────────────────────────────────────
# Всё кодом, как панели меню (CharacterSelectPanel.gd) — отдельного .tscn нет

func _build() -> void:
	_black = ColorRect.new()
	_black.color = BG_COLOR
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Тёплое пятно света по центру — как отсвет костра в темноте
	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.86, 0.6, 0.06), Color(0, 0, 0, 0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.45)
	grad_tex.fill_to = Vector2(1.0, 0.45)
	glow.texture = grad_tex
	_content.add_child(glow)

	var embers := Embers.new()
	embers.set_anchors_preset(Control.PRESET_FULL_RECT)
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(embers)

	# Лого из меню — тот же спрайт-лист, чуть меньше. smooth — сглаживание с
	# мип-картами (кадр 1024 px здесь уменьшается до 840, чётко)
	_logo = TextureRect.new()
	_logo.set_script(SpriteSheetAnimationScript)
	_logo.set("smooth", true)
	var logo_mat := ShaderMaterial.new()
	logo_mat.shader = LOGO_SHADER
	logo_mat.set_shader_parameter("rect_size", Vector2(840, 420))
	_logo.material = logo_mat
	_logo.set_anchors_preset(Control.PRESET_CENTER)
	_logo.offset_left = -420.0
	_logo.offset_right = 420.0
	_logo.offset_top = -380.0
	_logo.offset_bottom = 40.0
	_content.add_child(_logo)
	_logo.call("setup_grid", LOGO_SHEET, 6, 6, 1.0 / 15.0)

	# Полоса прогресса: тонкая тусклая линия + золотая заливка + ромбик
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.offset_left = -260.0
	bar.offset_right = 260.0
	bar.offset_top = 110.0
	bar.offset_bottom = 112.0
	_content.add_child(bar)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.1)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(track)

	_bar_fill = ColorRect.new()
	_bar_fill.color = GOLD
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(0.0, 2.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_fill)

	_bar_tip = ColorRect.new()
	_bar_tip.color = GOLD_BRIGHT
	_bar_tip.size = Vector2(9.0, 9.0)
	_bar_tip.pivot_offset = _bar_tip.size / 2.0
	_bar_tip.rotation = PI / 4.0
	_bar_tip.position = Vector2(-4.5, 1.0 - 4.5)
	_bar_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_bar_tip)

	_loading_label = _make_label("ЗАГРУЗКА", 18, TEXT_DIM_COLOR)
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.offset_left = -260.0
	_loading_label.offset_right = 260.0
	_loading_label.offset_top = 128.0
	_loading_label.offset_bottom = 160.0
	_content.add_child(_loading_label)

	_tip_label = _make_label("", 22, TEXT_COLOR)
	_tip_label.add_theme_font_override("font", Style.italic_font())
	_tip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_label.offset_left = -700.0
	_tip_label.offset_right = 700.0
	_tip_label.offset_top = -130.0
	_tip_label.offset_bottom = -80.0
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_tip_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Style.caps_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Угольки, медленно поднимающиеся со дна экрана. Рисуем руками, а не
## частицами: GPUParticles на CanvasLayer поверх смены сцены ведут себя
## капризно, а тут их всего несколько десятков
class Embers extends Control:
	const COUNT := 45
	var _parts := []

	func _ready() -> void:
		for i in COUNT:
			_parts.append(_spawn(true))

	func _spawn(anywhere: bool) -> Dictionary:
		var s := get_viewport_rect().size
		return {
			"pos": Vector2(randf() * s.x, (randf() if anywhere else 1.0) * s.y + 10.0),
			"speed": randf_range(18.0, 55.0),
			"drift": randf_range(0.4, 1.4),
			"phase": randf() * TAU,
			"radius": randf_range(1.0, 2.6),
			"life": randf_range(0.35, 1.0),
		}

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var s := get_viewport_rect().size
		for i in _parts.size():
			var p: Dictionary = _parts[i]
			p.phase += delta * p.drift
			p.pos += Vector2(sin(p.phase) * 12.0, -p.speed) * delta
			if p.pos.y < -10.0 or p.pos.x < -20.0 or p.pos.x > s.x + 20.0:
				_parts[i] = _spawn(false)
		queue_redraw()

	func _draw() -> void:
		var s := get_viewport_rect().size
		for p in _parts:
			# Ближе к верху уголёк остывает и тает
			var fade: float = clampf(p.pos.y / s.y, 0.0, 1.0)
			var flicker: float = 0.6 + 0.4 * sin(p.phase * 5.0)
			var a: float = fade * flicker * p.life
			draw_circle(p.pos, p.radius * 2.6, Color(1.0, 0.45, 0.1, a * 0.12))
			draw_circle(p.pos, p.radius, Color(1.0, 0.72, 0.3, a * 0.85))
