# res://ui/inventory_ui.gd
extends CanvasLayer

signal closed

# Палитра — в тон главному меню и экрану выбора героя: тёплое тёмное золото
# на почти чёрном
const COLOR_FRAME_FILL  = Color(0.062, 0.054, 0.046, 0.97)
# Ячейки темнее окна — читаются как утопленные гнёзда, а не как плашки поверх
const COLOR_CELL_FILL   = Color(0.03, 0.027, 0.024, 0.95)
const COLOR_BORDER      = Color(0.45, 0.35, 0.15, 1.0)
const COLOR_BORDER_HI   = Color(0.80, 0.62, 0.22, 1.0)
const COLOR_TEXT        = Color(0.88, 0.81, 0.68, 1.0)
const COLOR_TEXT_DIM    = Color(0.56, 0.50, 0.40, 1.0)
const COLOR_TEXT_GOLD   = Color(0.96, 0.76, 0.34, 1.0)
const COLOR_DIVIDER     = Color(0.52, 0.42, 0.24, 0.55)

const COLOR_WARN        = Color(0.85, 0.35, 0.20, 1.0)

const GRID_COLS := 3
const GRID_ROWS := 4

const TAB_INVENTORY := 0
const TAB_SKILLS    := 1
const TAB_SETTINGS  := 2

# Настройки — та же панель, что и в главном меню, а не её копия: значения живут
# в автозагрузке GameSettings, и второй реализации взяться неоткуда
const SettingsPanelScript := preload("res://Main_Menu/scripts/SettingsPanel.gd")

# Орнаменты — те же скрипты, что у главного меню и экрана выбора героя, чтобы
# весь интерфейс говорил на одном визуальном языке. Через set_script, а не
# class_name: глобальный кэш классов в этом проекте уже подводил
const OrnateFrameScript := preload("res://Main_Menu/scripts/OrnateFrame.gd")
const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")
const OrnamentSeparatorScript := preload("res://Main_Menu/scripts/OrnamentSeparator.gd")
const GlyphIconScript := preload("res://Main_Menu/scripts/GlyphIcon.gd")

# ─── UI-ЗВУКИ ──────────────────────────────────────────────────────────────────
const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_OPEN := preload("res://Sound/openUI_sound.mp3")

const SkillTreePanelScript := preload("res://Inventory/ui/skill_tree_panel.gd")
var _ui_audio: AudioStreamPlayer

func _play_ui_sound(stream: AudioStream) -> void:
	_ui_audio.stream = stream
	_ui_audio.play()

var _ability_system: AbilitySystem
var _inventory_system: InventorySystem
## Сам персонаж (сейчас всегда рыцарь — InventoryUI есть только в player.tscn).
## Нужен деревьям навыков: skill_points/unlocked_skills/try_unlock_skill живут
## на нём, не здесь (см. Inventory/ui/skill_tree_panel.gd)
var _player: Node

## Фон отдельно от _root: _root при открытии "наплывает" из масштаба 0.96, и
## если бы фон масштабировался вместе с ним, по краям экрана на эти доли
## секунды проглядывал бы мир
var _backdrop: Control
var _root: Control
var _grid_slots: Array[Control] = []
var _selected_index: int = -1
var _hover_index: int = -1

# Оверлеи поверх инвентаря (настройки / навыки). Пока хоть один открыт, Esc
# закрывает его, а не весь инвентарь
var _settings_panel: Control
var _skills_panel: Control
var _is_closing := false

# Экран выбора дерева навыков (три панели) и экран самого дерева — второй
# пока заглушка (см. _build_skills_panel), сами деревья отдельной задачей
const SKILL_TREE_NAMES := [
	"РУНЫ СТОЙКОСТИ",
	"КЛЫК БЕРСЕРКА",
	"ВОЛЯ ЭЙНХЕРИЯ",
]
## Параллельно SKILL_TREE_NAMES — путь к иконке или "", если своей ещё нет
## (тогда карточка остаётся текстовой, как раньше)
const SKILL_TREE_ICONS := [
	"res://UI/icons/runes_of_endurance.png",
	"",
	"",
]
var _skill_tree_selector: Control
var _skill_tree_detail: Control
var _skills_pw := 0.0
var _skills_ph := 0.0
# Рамка окна "НАВЫКИ" — меняет размер между экраном выбора дерева (обычный
# размер, карточки-деревья трогать не просили) и экраном самого дерева
# (крупнее — под сетку узлов), см. _resize_skills_frame/_on_tree_selected
var _skills_frame: Control
var _skills_divider: Control
var _skills_back_btn: Button

var _tab_buttons: Array[Button] = []
var _current_tab := TAB_INVENTORY

var _detail_icon: TextureRect
var _detail_icon_frame: Control
var _detail_name: Label
var _detail_type: Label
var _detail_count: Label
var _detail_max_count: Label
var _detail_effect: Label
var _btn_equip: Button
var _btn_equip_deco: Control
var _quick_slot_header: Label
var _quick_slot_status: Label
# Быстрые слоты рисуются дважды: крупно в правой колонке "БЫСТРЫЙ СЛОТ" и
# мини-строкой "Быстрый доступ N/3" внизу слева — как на референсе
var _big_slots: Array[Control] = []
var _mini_slots: Array[Control] = []

var _screen: Vector2
# _panel_w/_panel_h — габариты, от которых считаются размеры окна "НАВЫКИ"
# (_selector_frame_size/_detail_frame_size). Остаются прежними, чтобы
# переделка вёрстки инвентаря не сдвинула уже настроенное дерево навыков
var _panel_w: float
var _panel_h: float
var _frame_pos: Vector2
var _frame_size: Vector2
var _pad: float
var _left_w: float
var _right_x: float
var _mid_x: float
var _mid_w: float
var _btn_y: float
var _slot_size: Vector2
var _slot_gap: float
var _grid_x: float
var _grid_y: float


func _ready() -> void:
	visible = false
	# продолжаем работать во время паузы, чтобы инвентарь оставался интерактивным
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_audio = AudioStreamPlayer.new()
	add_child(_ui_audio)


func init(ability_system: AbilitySystem, inventory_system: InventorySystem, player: Node = null) -> void:
	_ability_system = ability_system
	_inventory_system = inventory_system
	_player = player
	# Заряды списывает быстрый слот, а лежат они в сумке — связываем одно с другим
	_ability_system.inventory = inventory_system
	_inventory_system.count_changed.connect(_on_count_changed)
	_build_ui()


func open() -> void:
	if visible:
		return
	# ставим игру на паузу — враги останавливаются и не бьют игрока
	get_tree().paused = true
	_is_closing = false
	_hover_index = -1
	_play_ui_sound(SOUND_OPEN)
	visible = true
	_refresh_grid()
	_backdrop.modulate.a = 0.0
	_root.modulate = Color(1, 1, 1, 0)
	_root.scale = Vector2(0.96, 0.96)
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.22)
	tw.tween_property(_root, "modulate", Color.WHITE, 0.18)
	tw.tween_property(_root, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func close() -> void:
	# Esc может прилететь дважды (пока идёт твин закрытия) — без флага мир
	# снимался бы с паузы повторно и сигнал closed летел бы два раза
	if _is_closing or not visible:
		return
	_is_closing = true
	_play_ui_sound(SOUND_OPEN)
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.16)
	tw.tween_property(_root, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_property(_root, "scale", Vector2(0.96, 0.96), 0.14)
	await tw.finished
	visible = false
	_is_closing = false
	# снимаем паузу — мир снова оживает
	get_tree().paused = false
	emit_signal("closed")


func add_item(ability: Ability) -> void:
	# Стаки и счётчики целиком на стороне InventorySystem — UI только рисует
	if _inventory_system == null:
		push_warning("[Инвентарь] add_item до init() — предмет потерян: %s" % ability.ability_name)
		return
	_inventory_system.add_item(ability)
	if visible:
		_refresh_grid()


## Открыт ли поверх инвентаря какой-то подраздел — по этому же признаку player.gd
## понимает, что Esc сейчас не его
func has_overlay_open() -> bool:
	if is_instance_valid(_skills_panel) and _skills_panel.visible:
		return true
	if is_instance_valid(_settings_panel) and _settings_panel.visible:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# Помечаем ввод обработанным, чтобы player.gd не закрыл инвентарь вторым
		# обработчиком того же нажатия
		get_viewport().set_input_as_handled()
		# Панель настроек гасит Esc сама (у неё свой _unhandled_input и она в
		# дереве ниже), сюда событие доходит только когда её нет
		if is_instance_valid(_skills_panel) and _skills_panel.visible:
			_close_skills()
			return
		close()
		return

	# E работает на весь экран инвентаря, а не только по сфокусированной ячейке:
	# у слотов gui_input срабатывает лишь при фокусе, поэтому подсказка "[E] в
	# слот" без этого обработчика была бы враньём
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if has_overlay_open():
			return
		get_viewport().set_input_as_handled()
		_on_equip_pressed()


# ─────────────────────────────────────────────
# BUILD UI
# ─────────────────────────────────────────────

func _build_ui() -> void:
	_screen = get_viewport().get_visible_rect().size
	_panel_w = _screen.x - 60.0
	_panel_h = _screen.y - 60.0

	# Главное окно — по центру, с запасом сверху под полосу вкладок и снизу
	# под подсказки клавиш
	_frame_pos = Vector2(round(_screen.x * 0.047), round(_screen.y * 0.112))
	_frame_size = Vector2(
		_screen.x - _frame_pos.x * 2.0,
		_screen.y - _frame_pos.y - round(_screen.y * 0.07))

	# Три колонки внутри окна: сетка предметов | описание | быстрые слоты.
	# Доли сняты с референса
	_pad = 30.0
	_left_w = round(_frame_size.x * 0.405)
	_right_x = round(_frame_size.x * 0.815)
	_mid_x = _left_w + 40.0
	_mid_w = _right_x - 34.0 - _mid_x
	_btn_y = _frame_size.y - 104.0

	_slot_gap = 16.0
	_grid_x = _pad
	_grid_y = 84.0
	# справа от сетки место под декоративную полосу прокрутки, снизу — под
	# строку "Быстрый доступ"
	var grid_w := _left_w - _pad - 58.0
	var grid_h := _frame_size.y - 110.0 - _grid_y
	_slot_size = Vector2(
		floor((grid_w - _slot_gap * (GRID_COLS - 1)) / GRID_COLS),
		floor((grid_h - _slot_gap * (GRID_ROWS - 1)) / GRID_ROWS))

	_build_backdrop()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Шрифт меню (sikandinarie.ttf) здесь не годится: в нём нет кириллицы, и
	# весь русский текст всё равно падал в запасной гротеск Godot, а шрифт меню
	# доставался только цифрам — где его единица неотличима от "l" ("x1"
	# читалось как "xl"). Системная антиква с кириллицей даёт засечки, как на
	# референсе, и нормальные цифры. Нет ни одного шрифта из списка —
	# SystemFont сам откатывается к стандартному, ничего не ломается
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(
		["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	var font_theme := Theme.new()
	font_theme.default_font = serif
	_root.theme = font_theme
	add_child(_root)

	var frame := _make_panel(_frame_pos, _frame_size)
	frame.set("corner_length", 38.0)
	frame.set("corner_width", 2.0)
	_root.add_child(frame)

	# Вкладки — после окна: полоса заходит на его верхнюю кайму и должна её
	# перекрыть, как язычок, а не прятаться под ней
	_build_tabs()

	_build_column_dividers(frame)
	_build_grid(frame)
	_build_detail_panel(frame)
	_build_quick_column(frame)
	_build_quick_slot_bar(frame)
	_build_equip_button(frame)
	_build_hints()

	# Стартовое состояние правой части — подсказка "Выберите предмет" вместо
	# пустоты, и заодно первая отрисовка сетки и быстрых слотов
	_select_slot(-1, false)


# Фон под инвентарём: мир не просвечивает совсем (игра всё равно на паузе),
# но и не плоская чернота — тёплое свечение по центру, отсвет над вкладками,
# зарево снизу и редкие угли, поднимающиеся от него, как от тлеющих руин из
# главного меню. Всё процедурное, без картинок
func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.012, 0.010, 0.009, 1.0)
	# ColorRect по умолчанию MOUSE_FILTER_STOP — ловит клики мимо интерфейса,
	# чтобы они не уходили в мир под инвентарём
	_backdrop.add_child(base)

	# Мягкое тёплое свечение по центру — окну есть на чём "стоять"
	_backdrop.add_child(_make_radial(Rect2(Vector2.ZERO, _screen),
		PackedFloat32Array([0.0, 0.5, 1.0]),
		PackedColorArray([
			Color(0.12, 0.09, 0.06, 0.9),
			Color(0.055, 0.042, 0.03, 0.5),
			Color(0.0, 0.0, 0.0, 0.0)])))

	# Отсвет над полосой вкладок
	_backdrop.add_child(_make_radial(
		Rect2(Vector2(_screen.x * 0.25, -_screen.y * 0.14), Vector2(_screen.x * 0.5, _screen.y * 0.38)),
		PackedFloat32Array([0.0, 1.0]),
		PackedColorArray([Color(0.42, 0.28, 0.13, 0.2), Color(0.0, 0.0, 0.0, 0.0)])))

	# Зарево снизу — откуда поднимаются угли
	var ember_glow := _make_linear(
		Rect2(Vector2(0.0, _screen.y * 0.6), Vector2(_screen.x, _screen.y * 0.4)),
		Color(0.0, 0.0, 0.0, 0.0), Color(0.26, 0.09, 0.025, 0.24), true)
	_backdrop.add_child(ember_glow)

	_backdrop.add_child(_make_embers())

	# Виньетка поверх всего — края экрана уходят в полную черноту
	_backdrop.add_child(_make_radial(Rect2(Vector2.ZERO, _screen),
		PackedFloat32Array([0.0, 0.5, 1.0]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.82)])))


func _make_embers() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.position = Vector2(_screen.x / 2.0, _screen.y + 12.0)
	p.amount = 64
	p.lifetime = 9.0
	# Предпрогрев — при первом открытии угли уже висят в воздухе, а не
	# начинают вылетать с пустого экрана
	p.preprocess = 9.0
	p.randomness = 0.6

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(_screen.x * 0.55, 8.0, 1.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 18.0
	mat.initial_velocity_min = 35.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3(0.0, -6.0, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.8
	mat.turbulence_noise_scale = 3.0
	mat.turbulence_influence_min = 0.03
	mat.turbulence_influence_max = 0.08
	mat.scale_min = 0.12
	mat.scale_max = 0.32

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.62, 0.22, 0.0),
		Color(1.0, 0.58, 0.18, 0.75),
		Color(0.95, 0.35, 0.08, 0.45),
		Color(0.5, 0.12, 0.02, 0.0),
	])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	p.process_material = mat

	# Мягкая круглая точка вместо квадратного пикселя
	var dot := Gradient.new()
	dot.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	dot.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var dot_tex := GradientTexture2D.new()
	dot_tex.gradient = dot
	dot_tex.fill = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to = Vector2(1.0, 0.5)
	dot_tex.width = 32
	dot_tex.height = 32
	p.texture = dot_tex

	# Аддитивное смешивание — угли светятся, а не лежат плоскими кружками
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = glow
	return p


# Вкладки разделов — полосой над окном, по центру. Порядок слева направо:
# Инвентарь (открыт по умолчанию), Навыки, Настройки. Активная — золотой текст,
# ромбик над ней и золотая черта с ромбиком снизу
func _build_tabs() -> void:
	var tab_defs := [
		["ИНВЕНТАРЬ", TAB_INVENTORY],
		["НАВЫКИ",    TAB_SKILLS],
		["НАСТРОЙКИ", TAB_SETTINGS],
	]
	var tab_w := 300.0
	var strip_h := 66.0
	var strip_w := tab_w * tab_defs.size()
	var strip_pos := Vector2((_screen.x - strip_w) / 2.0, _frame_pos.y - strip_h + 10.0)

	var strip := _make_frame()
	strip.position = strip_pos - Vector2(26.0, 0.0)
	strip.size = Vector2(strip_w + 52.0, strip_h)
	strip.set("fill_color", Color(0.034, 0.03, 0.027, 0.98))
	strip.set("corner_length", 18.0)
	_root.add_child(strip)

	for i in range(1, tab_defs.size()):
		var sep := _make_fade_line(strip_h - 22.0, true, COLOR_DIVIDER)
		sep.position = strip_pos + Vector2(i * tab_w, 11.0)
		_root.add_child(sep)

	_tab_buttons.clear()
	for i in tab_defs.size():
		var def: Array = tab_defs[i]
		var tab_id: int = def[1]
		var btn := _make_tab_button(def[0], strip_pos + Vector2(i * tab_w, 0.0),
			Vector2(tab_w, strip_h))
		btn.pressed.connect(func(): _on_tab_pressed(tab_id))
		_root.add_child(btn)
		_tab_buttons.append(btn)

	_update_tab_visuals()


func _make_tab_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 24)

	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)

	btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_GOLD)

	# Индикатор активной вкладки: ромбик на верхней кромке полосы и золотая
	# черта с ромбиком под текстом. Показывается только у текущей вкладки
	var ind := Control.new()
	ind.name = "Indicator"
	ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ind.size = sz
	btn.add_child(ind)

	var top := _make_diamond(14.0)
	top.position = Vector2(sz.x / 2.0 - 7.0, -7.0)
	ind.add_child(top)

	var line := _make_fade_line(sz.x * 0.72, false, COLOR_BORDER_HI, 2.0)
	line.position = Vector2(sz.x * 0.14, sz.y - 14.0)
	ind.add_child(line)

	var bottom := _make_diamond(12.0)
	bottom.position = Vector2(sz.x / 2.0 - 6.0, sz.y - 19.0)
	ind.add_child(bottom)

	return btn


func _update_tab_visuals() -> void:
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		var active := i == _current_tab
		btn.add_theme_color_override("font_color", COLOR_TEXT_GOLD if active else COLOR_TEXT_DIM)
		(btn.get_node("Indicator") as Control).visible = active


func _set_current_tab(tab: int) -> void:
	_current_tab = tab
	_update_tab_visuals()


func _on_tab_pressed(id: int) -> void:
	if id == _current_tab:
		return
	match id:
		TAB_INVENTORY:
			_play_ui_sound(SOUND_CHOICE)
			if is_instance_valid(_skills_panel) and _skills_panel.visible:
				_skills_panel.visible = false
			if is_instance_valid(_settings_panel) and _settings_panel.visible:
				_settings_panel.close()
			_set_current_tab(TAB_INVENTORY)
		TAB_SKILLS:
			if is_instance_valid(_settings_panel) and _settings_panel.visible:
				_settings_panel.close()
			_open_skills()
		TAB_SETTINGS:
			if is_instance_valid(_skills_panel) and _skills_panel.visible:
				_skills_panel.visible = false
			_open_settings()


# Вертикальные разделители колонок — гаснущие к концам линии с ромбиком
func _build_column_dividers(parent: Control) -> void:
	var left := _make_fade_line(_frame_size.y - 44.0, true, COLOR_DIVIDER)
	left.position = Vector2(_left_w, 22.0)
	parent.add_child(left)
	var ld := _make_diamond(12.0)
	ld.position = Vector2(_left_w - 6.0, _frame_size.y / 2.0 - 6.0)
	parent.add_child(ld)

	# Правый — только вдоль колонки быстрых слотов: под ней широкая кнопка
	# действия тянется через обе колонки
	var right_len := _btn_y - 70.0
	var right := _make_fade_line(right_len, true, COLOR_DIVIDER)
	right.position = Vector2(_right_x, 22.0)
	parent.add_child(right)
	var rd := _make_diamond(10.0)
	rd.position = Vector2(_right_x - 5.0, 22.0 + right_len * 0.12)
	parent.add_child(rd)


func _build_grid(parent: Control) -> void:
	var emblem := _make_glyph("medallion", COLOR_BORDER_HI, 40.0)
	emblem.position = Vector2(_pad, 20.0)
	parent.add_child(emblem)

	var hdr := _make_label("ИНВЕНТАРЬ", 22)
	hdr.position = Vector2(_pad + 52.0, 24.0)
	parent.add_child(hdr)

	var hdr_line := _make_fade_line(_left_w - _pad * 2.0 - 30.0, false, COLOR_DIVIDER)
	hdr_line.position = Vector2(_pad + 30.0, 66.0)
	parent.add_child(hdr_line)

	for row in GRID_ROWS:
		for col in GRID_COLS:
			var idx := row * GRID_COLS + col
			var pos := Vector2(
				_grid_x + col * (_slot_size.x + _slot_gap),
				_grid_y + row * (_slot_size.y + _slot_gap)
			)
			var slot := _build_slot(idx, pos)
			parent.add_child(slot)
			_grid_slots.append(slot)

	# Декоративная "полоса прокрутки" справа от сетки — как на референсе.
	# Настоящей прокрутки нет: ячеек ровно столько, сколько видно
	var grid_h := GRID_ROWS * _slot_size.y + (GRID_ROWS - 1) * _slot_gap
	var rail_x := _grid_x + GRID_COLS * (_slot_size.x + _slot_gap) + 10.0
	var rail := _make_fade_line(grid_h, true, COLOR_DIVIDER)
	rail.position = Vector2(rail_x, _grid_y)
	parent.add_child(rail)
	for y in [_grid_y - 4.0, _grid_y + grid_h - 4.0]:
		var d := _make_diamond(8.0)
		d.position = Vector2(rail_x - 4.0, y)
		parent.add_child(d)


func _build_slot(idx: int, pos: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = _slot_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := _make_frame()
	frame.name = "Frame"
	frame.size = _slot_size
	frame.set("fill_color", COLOR_CELL_FILL)
	frame.set("corner_length", 16.0)
	frame.set("show_cross", true)
	c.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(_slot_size.x * 0.18, 10.0)
	icon.size = Vector2(_slot_size.x * 0.64, _slot_size.y - 52.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(icon)

	var lbl := _make_label("", 17)
	lbl.name = "Name"
	lbl.position = Vector2(12.0, _slot_size.y - 36.0)
	lbl.size = Vector2(_slot_size.x - 24.0, 26.0)
	lbl.clip_text = true
	c.add_child(lbl)

	var cnt := _make_label("", 17)
	cnt.name = "Count"
	cnt.position = Vector2(_slot_size.x - 64.0, 6.0)
	cnt.size = Vector2(54.0, 24.0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	c.add_child(cnt)

	var area := Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(func(ev): _on_slot_input(ev, idx))
	area.mouse_entered.connect(func(): _on_slot_hover(idx, true))
	area.mouse_exited.connect(func(): _on_slot_hover(idx, false))
	c.add_child(area)

	return c


func _build_detail_panel(parent: Control) -> void:
	var x := _mid_x
	var w := _mid_w
	var icon_size := 168.0
	var text_w := w - icon_size - 24.0

	# Крупная иконка выбранного предмета — справа вверху колонки. Без выбора
	# прячется, и колонка выглядит как на референсе
	_detail_icon_frame = _make_frame()
	_detail_icon_frame.position = Vector2(x + w - icon_size, 30.0)
	_detail_icon_frame.size = Vector2(icon_size, icon_size)
	_detail_icon_frame.set("fill_color", COLOR_CELL_FILL)
	_detail_icon_frame.set("corner_length", 20.0)
	_detail_icon_frame.set("double_border", true)
	parent.add_child(_detail_icon_frame)

	_detail_icon = TextureRect.new()
	_detail_icon.position = Vector2(14.0, 14.0)
	_detail_icon.size = Vector2(icon_size - 28.0, icon_size - 28.0)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon_frame.add_child(_detail_icon)

	_detail_name = _make_label("", 34)
	_detail_name.position = Vector2(x, 34.0)
	_detail_name.size = Vector2(text_w, 46.0)
	_detail_name.clip_text = true
	parent.add_child(_detail_name)

	_detail_type = _make_label("", 19)
	_detail_type.position = Vector2(x, 86.0)
	_detail_type.size = Vector2(text_w, 26.0)
	_detail_type.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_detail_type)

	var y := 30.0 + icon_size + 22.0
	var sep := Control.new()
	sep.set_script(OrnamentSeparatorScript)
	sep.position = Vector2(x, y)
	sep.size = Vector2(w, 18.0)
	parent.add_child(sep)
	y += 36.0

	_detail_count = _add_stat_row(parent, "При себе", y)
	y += 36.0
	_detail_max_count = _add_stat_row(parent, "Макс. за сессию", y)
	y += 48.0

	_add_divider(parent, Vector2(x, y), w)
	y += 18.0

	var eff_hdr := _make_label("Эффект", 20)
	eff_hdr.position = Vector2(x, y)
	eff_hdr.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(eff_hdr)
	y += 34.0

	_detail_effect = _make_label("", 20)
	_detail_effect.position = Vector2(x, y)
	_detail_effect.size = Vector2(w, _btn_y - 56.0 - y)
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_detail_effect)


func _add_stat_row(parent: Control, caption: String, y: float) -> Label:
	var cap := _make_label(caption, 20)
	cap.position = Vector2(_mid_x, y)
	cap.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(cap)

	var val := _make_label("", 20)
	val.position = Vector2(_mid_x, y)
	val.size = Vector2(_mid_w, 28.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	parent.add_child(val)
	return val


# Правая колонка "БЫСТРЫЙ СЛОТ" — три крупные ячейки столбиком. Клик по
# занятой ячейке выбирает этот предмет в сетке слева
func _build_quick_column(parent: Control) -> void:
	var x := _right_x + 30.0
	var col_w := _frame_size.x - _right_x - 60.0

	var hdr := _make_label("БЫСТРЫЙ СЛОТ", 22)
	hdr.position = Vector2(x, 26.0)
	parent.add_child(hdr)

	var line := _make_fade_line(col_w, false, COLOR_DIVIDER)
	line.position = Vector2(x, 64.0)
	parent.add_child(line)

	var ss := minf(146.0, col_w)
	var y := 86.0
	_big_slots.clear()
	for i in AbilitySystem.MAX_SLOTS:
		var s := _build_quick_slot(Vector2(x, y), Vector2(ss, ss), true, i)
		parent.add_child(s)
		_big_slots.append(s)
		y += ss + 22.0


# Мини-строка внизу слева: сумка, "Быстрый доступ N/3" и три крошечные ячейки
func _build_quick_slot_bar(parent: Control) -> void:
	var y := _frame_size.y - 84.0

	var bag := _make_glyph("bag", COLOR_TEXT_DIM, 44.0)
	bag.position = Vector2(_pad, y + 10.0)
	parent.add_child(bag)

	_quick_slot_header = _make_label("", 17)
	_quick_slot_header.position = Vector2(_pad + 58.0, y)
	_quick_slot_header.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_quick_slot_header)

	_mini_slots.clear()
	for i in AbilitySystem.MAX_SLOTS:
		var s := _build_quick_slot(Vector2(_pad + 58.0 + i * 42.0, y + 30.0),
			Vector2(36.0, 36.0), false, i)
		parent.add_child(s)
		_mini_slots.append(s)

	# Строка обратной связи над кнопкой действия: "слоты заняты", "предмет
	# кончился" и т.п. Без неё отказ добавить четвёртый предмет был бы слышен
	# (звук denied), но не виден
	_quick_slot_status = _make_label("", 17)
	_quick_slot_status.position = Vector2(_mid_x, _btn_y - 38.0)
	_quick_slot_status.size = Vector2(_frame_size.x - 50.0 - _mid_x, 24.0)
	_quick_slot_status.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_quick_slot_status)


func _build_quick_slot(pos: Vector2, sz: Vector2, big: bool, index: int) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := _make_frame()
	frame.name = "Frame"
	frame.size = sz
	frame.set("fill_color", COLOR_CELL_FILL)
	frame.set("corner_length", 16.0 if big else 6.0)
	frame.set("corner_width", 1.5 if big else 1.0)
	c.add_child(frame)

	var inset := 16.0 if big else 4.0
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(inset, inset)
	icon.size = sz - Vector2(inset * 2.0, inset * 2.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(icon)

	if big:
		var area := Control.new()
		area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_quick_slot_clicked(index)
		)
		c.add_child(area)

	return c


# Широкая кнопка действия под колонками описания и быстрых слотов: двойная
# рамка, ромбики по краям и по центру сверху/снизу — как на референсе
func _build_equip_button(parent: Control) -> void:
	var w := _frame_size.x - 50.0 - _mid_x
	var h := 64.0

	_btn_equip = Button.new()
	_btn_equip.position = Vector2(_mid_x, _btn_y)
	_btn_equip.size = Vector2(w, h)
	_btn_equip.focus_mode = Control.FOCUS_NONE
	_btn_equip.add_theme_font_size_override("font_size", 20)
	_btn_equip.add_theme_color_override("font_color", COLOR_TEXT)
	_btn_equip.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
	_btn_equip.add_theme_color_override("font_pressed_color", COLOR_TEXT_GOLD)
	_btn_equip.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	_btn_equip.add_theme_stylebox_override("normal",
		_flat_box(Color(0.06, 0.052, 0.045, 0.95), Color(0.55, 0.44, 0.26, 0.7)))
	_btn_equip.add_theme_stylebox_override("hover",
		_flat_box(Color(0.13, 0.1, 0.065, 0.97), COLOR_BORDER_HI))
	_btn_equip.add_theme_stylebox_override("pressed",
		_flat_box(Color(0.04, 0.035, 0.03, 0.97), Color(0.55, 0.44, 0.26, 0.7)))
	_btn_equip.add_theme_stylebox_override("disabled",
		_flat_box(Color(0.05, 0.045, 0.04, 0.85), Color(0.35, 0.3, 0.22, 0.5)))
	_btn_equip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_btn_equip.pressed.connect(_on_equip_pressed)
	_btn_equip.disabled = true
	parent.add_child(_btn_equip)

	# Орнамент отдельной нодой поверх кнопки — чтобы у неактивной кнопки его
	# можно было приглушить целиком (_update_equip_deco)
	_btn_equip_deco = Control.new()
	_btn_equip_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_equip_deco.size = Vector2(w, h)
	_btn_equip.add_child(_btn_equip_deco)

	var inner := _make_frame()
	inner.position = Vector2(6.0, 6.0)
	inner.size = Vector2(w - 12.0, h - 12.0)
	inner.set("fill_color", Color(0.0, 0.0, 0.0, 0.0))
	inner.set("border_color", Color(0.55, 0.44, 0.26, 0.28))
	inner.set("corner_length", 10.0)
	_btn_equip_deco.add_child(inner)

	for p in [Vector2(-9.0, h / 2.0 - 9.0), Vector2(w - 9.0, h / 2.0 - 9.0)]:
		var d := _make_diamond(18.0)
		d.position = p
		_btn_equip_deco.add_child(d)
	for p in [Vector2(w / 2.0 - 6.0, -6.0), Vector2(w / 2.0 - 6.0, h - 6.0)]:
		var d := _make_diamond(12.0)
		d.position = p
		_btn_equip_deco.add_child(d)


func _update_equip_deco() -> void:
	if is_instance_valid(_btn_equip_deco):
		_btn_equip_deco.modulate.a = 0.4 if _btn_equip.disabled else 1.0


# Подсказки клавиш под окном справа — тот же вид "клавиша в рамке + подпись",
# что у экрана выбора героя. [E] не дублируем: он написан на самой кнопке
func _build_hints() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(_frame_pos.x + _frame_size.x - 520.0, _frame_pos.y + _frame_size.y + 14.0)
	row.size = Vector2(520.0, 38.0)
	_root.add_child(row)

	for h in [["ЛКМ", "ВЫБРАТЬ"], ["ESC", "ЗАКРЫТЬ"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 10)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pair)

		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := _flat_box(Color(0.08, 0.07, 0.06, 0.95), Color(COLOR_BORDER_HI, 0.7))
		style.set_corner_radius_all(3)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", style)
		pair.add_child(chip)

		var key := _make_label(h[0], 16)
		key.add_theme_color_override("font_color", COLOR_TEXT)
		chip.add_child(key)

		var txt := _make_label(h[1], 17)
		txt.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(txt)


# ─────────────────────────────────────────────
# LOGIC
# ─────────────────────────────────────────────

func _refresh_grid() -> void:
	var items := _inventory_system.get_all()
	for i in _grid_slots.size():
		var slot    := _grid_slots[i]
		var frame   := slot.get_node("Frame")
		var icon    := slot.get_node("Icon") as TextureRect
		var name_l  := slot.get_node("Name") as Label
		var count_l := slot.get_node("Count") as Label

		if i < items.size():
			var ab      := items[i] as Ability
			icon.texture = ab.icon
			name_l.text  = ab.ability_name
			var cnt := _inventory_system.get_count(ab.ability_name)
			count_l.text = "x%d" % cnt
			# Последний заряд подсвечиваем красным: предмет вот-вот исчезнет из
			# сумки, и это должно быть видно ещё до того, как игрок его потратит
			count_l.add_theme_color_override(
				"font_color", COLOR_WARN if cnt <= 1 else COLOR_TEXT_GOLD)
			frame.set("show_cross", false)
		else:
			icon.texture  = null
			name_l.text   = ""
			count_l.text  = ""
			frame.set("show_cross", true)

		frame.set("highlight", _slot_highlight(i, items.size()))

	_refresh_quick_slot_preview()


## Выбранная ячейка — полное золото, наведённая — наполовину. Пустые ячейки
## не подсвечиваются: выбирать в них нечего
func _slot_highlight(i: int, item_count: int) -> float:
	if i >= item_count:
		return 0.0
	if i == _selected_index:
		return 1.0
	if i == _hover_index:
		return 0.45
	return 0.0


func _refresh_quick_slot_preview() -> void:
	if _ability_system == null:
		return

	var used := _ability_system.abilities.size()
	if is_instance_valid(_quick_slot_header):
		_quick_slot_header.text = "Быстрый доступ  %d/%d" % [used, AbilitySystem.MAX_SLOTS]

	# Рисуем ВСЕ ячейки, включая пустые — так видно, сколько места осталось,
	# а не только то, что уже занято
	for i in AbilitySystem.MAX_SLOTS:
		var ab: Ability = _ability_system.abilities[i] if i < used else null
		var active := ab != null and i == _ability_system.current_index
		if i < _big_slots.size():
			_apply_quick_slot(_big_slots[i], ab, active, true)
		if i < _mini_slots.size():
			_apply_quick_slot(_mini_slots[i], ab, active, false)


func _apply_quick_slot(slot: Control, ab: Ability, active: bool, cross_when_empty: bool) -> void:
	var frame := slot.get_node("Frame")
	var icon := slot.get_node("Icon") as TextureRect
	icon.texture = ab.icon if ab != null else null
	frame.set("show_cross", ab == null and cross_when_empty)
	frame.set("highlight", 1.0 if active else 0.0)


# play_sound=false — для перерисовки после действия (экипировка, трата заряда):
# карточка справа пересобирается тем же кодом, но щелчок выбора звучать не должен
func _select_slot(idx: int, play_sound := true) -> void:
	var items := _inventory_system.get_all()
	_selected_index = idx

	if idx >= 0 and idx < items.size():
		if play_sound:
			_play_ui_sound(SOUND_CHOICE)
		var ab       := items[idx] as Ability
		var cnt      := _inventory_system.get_count(ab.ability_name)
		var max_cnt  := _get_max_count(ab.ability_name)
		var equipped := _ability_system.has_ability(ab.ability_name)

		_detail_icon.texture     = ab.icon
		_detail_icon_frame.visible = true
		_detail_name.text        = ab.ability_name
		_detail_name.add_theme_color_override("font_color", COLOR_TEXT)
		_detail_type.text        = "Расходуемое  •  в слоте" if equipped else "Расходуемое"
		_detail_effect.text      = ab.description
		_detail_count.text       = "%d / %d" % [cnt, max_cnt]
		_detail_max_count.text   = "%d" % max_cnt
		# Кнопка работает как переключатель: повторное нажатие на предмет,
		# который уже в быстром доступе, освобождает слот. Без этого при трёх
		# занятых ячейках поменять набор было бы нечем
		_btn_equip.text     = "[E]   УБРАТЬ ИЗ СЛОТА" if equipped else "[E]   В БЫСТРЫЙ СЛОТ"
		_btn_equip.disabled = false
		_set_status("")
	else:
		# Ничего не выбрано — вместо пустой колонки подсказка, что делать
		_detail_icon.texture     = null
		_detail_icon_frame.visible = false
		_detail_name.text        = "Выберите предмет"
		_detail_name.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_type.text        = "Нажмите на ячейку инвентаря"
		_detail_effect.text      = ""
		_detail_count.text       = "—"
		_detail_max_count.text   = "—"
		_btn_equip.text          = "[E]   В БЫСТРЫЙ СЛОТ"
		_btn_equip.disabled      = true

	_update_equip_deco()
	_refresh_grid()


func _get_max_count(ability_name: String) -> int:
	match ability_name:
		"Мёд Поэзии":        return 5
		"Песнь Валькирии":   return 3
		"Эликсир Вальгаллы": return 3
		_:                   return 1


func _on_slot_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(idx)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_equip_pressed()


func _on_slot_hover(idx: int, entered: bool) -> void:
	if entered:
		_hover_index = idx
	elif _hover_index == idx:
		_hover_index = -1
	var frame := _grid_slots[idx].get_node("Frame")
	frame.set("highlight", _slot_highlight(idx, _inventory_system.get_all().size()))


func _on_quick_slot_clicked(slot_index: int) -> void:
	if _ability_system == null or slot_index >= _ability_system.abilities.size():
		return
	var ab := _ability_system.abilities[slot_index]
	var items := _inventory_system.get_all()
	for i in items.size():
		if (items[i] as Ability).ability_name == ab.ability_name:
			_select_slot(i)
			return


func _on_equip_pressed() -> void:
	var items := _inventory_system.get_all()
	if _selected_index < 0 or _selected_index >= items.size():
		return
	var ab: Ability = items[_selected_index] as Ability

	# Уже в слоте — снимаем (переключатель), освобождая место под другой предмет
	var slot := _ability_system.find_slot(ab.ability_name)
	if slot != -1:
		_ability_system.remove_ability(slot)
		_play_ui_sound(SOUND_CHOICE)
		# Перерисовку делаем ДО статуса: _select_slot чистит строку сообщения
		_select_slot(_selected_index, false)
		_set_status("Убрано из быстрого доступа: %s" % ab.ability_name, COLOR_TEXT_DIM)
		return

	if _ability_system.is_full():
		_play_ui_sound(SOUND_DENIED)
		_set_status("Быстрый доступ заполнен (%d/%d) — сначала уберите предмет"
			% [_ability_system.abilities.size(), AbilitySystem.MAX_SLOTS], COLOR_WARN)
		return

	if not _inventory_system.has_charges(ab.ability_name):
		_play_ui_sound(SOUND_DENIED)
		_set_status("Предмет закончился", COLOR_WARN)
		return

	_ability_system.add_ability(ab)
	_play_ui_sound(SOUND_ACCEPT)
	_select_slot(_selected_index, false)
	_set_status("В быстром доступе: %s" % ab.ability_name, COLOR_TEXT_GOLD)


func _set_status(text: String, color := COLOR_TEXT_DIM) -> void:
	if not is_instance_valid(_quick_slot_status):
		return
	_quick_slot_status.text = text
	_quick_slot_status.add_theme_color_override("font_color", color)


# Заряды могли измениться, пока инвентарь открыт (нельзя — игра на паузе) или
# закрыт (обычный случай: применили способность в бою). Перерисовываем только
# когда окно на экране — иначе это лишняя работа каждый раз
func _on_count_changed(_item_name: String, _count: int) -> void:
	if visible:
		# Через _select_slot, а не просто _refresh_grid: если предмет кончился и
		# выпал из сумки, карточка справа обязана перестроиться под новый список
		_select_slot(_selected_index, false)


# ─────────────────────────────────────────────
# РАЗДЕЛЫ: НАСТРОЙКИ / НАВЫКИ
# ─────────────────────────────────────────────

func _open_settings() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	if not is_instance_valid(_settings_panel):
		# Панель из главного меню создаётся скриптом, без .tscn — поэтому new()
		# по самому скрипту, а не instantiate() по сцене
		_settings_panel = SettingsPanelScript.new()
		_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Закрыта могла быть и через Esc внутри самой панели — в этом случае
		# вкладку "Настройки" тоже нужно снять, иначе она останется подсвеченной
		_settings_panel.closed.connect(func(): _set_current_tab(TAB_INVENTORY))
		# Добавляем в _root последним — значит, рисуется поверх всей вёрстки
		# инвентаря и перехватывает клики по ней
		_root.add_child(_settings_panel)
	_settings_panel.open()
	_set_current_tab(TAB_SETTINGS)


func _open_skills() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	if not is_instance_valid(_skills_panel):
		_skills_panel = _build_skills_panel()
		_root.add_child(_skills_panel)
	# Каждый заход — заново с выбора дерева, а не там, где бросили в прошлый раз
	if is_instance_valid(_skill_tree_detail):
		_skill_tree_detail.visible = false
	if is_instance_valid(_skill_tree_selector):
		_skill_tree_selector.visible = true
	if is_instance_valid(_skills_back_btn):
		_skills_back_btn.visible = true
	if is_instance_valid(_skills_frame):
		var sz := _selector_frame_size()
		_resize_skills_frame(sz.x, sz.y)
	_skills_panel.visible = true
	_skills_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_skills_panel, "modulate", Color.WHITE, 0.18)
	_set_current_tab(TAB_SKILLS)


func _close_skills() -> void:
	if not is_instance_valid(_skills_panel):
		return
	_play_ui_sound(SOUND_OPEN)
	_skills_panel.visible = false
	_set_current_tab(TAB_INVENTORY)


# Пока это только каркас раздела: сетки навыков и прокачки ещё нет, но место под
# неё уже занято — чтобы кнопка в шапке вела в настоящий экран, а не в пустоту
func _build_skills_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.02, 0.72)
	root.add_child(dim)

	# Шире прежней заглушки (0.7) — три дерева в ряд нужны панели пошире.
	# Экран самого дерева (сетка узлов) крупнее — см. _detail_frame_size()
	var sel_size := _selector_frame_size()
	var pw := sel_size.x
	var ph := sel_size.y
	_skills_pw = pw
	_skills_ph = ph
	_skills_frame = _make_panel(
		Vector2((_screen.x - pw) / 2.0, (_screen.y - ph) / 2.0), Vector2(pw, ph))
	root.add_child(_skills_frame)

	var title := _make_label("НАВЫКИ", 30)
	title.position = Vector2(32, 22)
	title.add_theme_color_override("font_color", COLOR_BORDER_HI)
	_skills_frame.add_child(title)

	_skills_divider = _add_divider(_skills_frame, Vector2(20, 68), pw - 40.0)

	_skill_tree_selector = _build_tree_selector(pw, ph)
	_skills_frame.add_child(_skill_tree_selector)

	_skill_tree_detail = Control.new()
	_skill_tree_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_tree_detail.visible = false
	_skills_frame.add_child(_skill_tree_detail)

	_skills_back_btn = _make_button("[ ESC ]  НАЗАД", Vector2((pw - 220.0) / 2.0, ph - 76.0), Vector2(220, 44))
	_skills_back_btn.pressed.connect(_close_skills)
	_skills_frame.add_child(_skills_back_btn)

	return root


## Обычный размер — экран выбора дерева (три карточки). Их самих трогать не
## просили, поэтому этот размер остаётся как был
func _selector_frame_size() -> Vector2:
	return Vector2(_panel_w * 0.9, _panel_h * 0.8)


## Крупнее — экран самого дерева (сетка узлов), под неё нужно больше места
func _detail_frame_size() -> Vector2:
	return Vector2(_panel_w * 0.97, _panel_h * 0.92)


## Меняет размер/позицию рамки окна "НАВЫКИ" и всего, что зависит от pw/ph
## напрямую (разделитель, постоянная кнопка "[ESC] НАЗАД") — вызывается при
## переходе между экраном выбора дерева и экраном самого дерева
func _resize_skills_frame(pw: float, ph: float) -> void:
	_skills_frame.position = Vector2((_screen.x - pw) / 2.0, (_screen.y - ph) / 2.0)
	_skills_frame.size = Vector2(pw, ph)
	_skills_divider.size.x = pw - 40.0
	_skills_back_btn.position = Vector2((pw - 220.0) / 2.0, ph - 76.0)
	_skills_pw = pw
	_skills_ph = ph


## Три большие кликабельные панели в ряд — одна на каждое дерево
## (SKILL_TREE_NAMES). Клик открывает _skill_tree_detail (пока заглушка,
## сами деревья — отдельная задача, см. договорённость в чате)
func _build_tree_selector(pw: float, ph: float) -> Control:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var top_margin := 100.0
	var bottom_margin := 100.0
	var side_margin := 40.0
	var gap := 24.0
	var tree_w := (pw - side_margin * 2.0 - gap * (SKILL_TREE_NAMES.size() - 1)) / SKILL_TREE_NAMES.size()
	var tree_h := ph - top_margin - bottom_margin

	for i in SKILL_TREE_NAMES.size():
		var x := side_margin + i * (tree_w + gap)
		# Текст пустой — название теперь отдельным Label внизу карточки, а не
		# встроенным текстом кнопки (см. label ниже)
		var card := _make_button("", Vector2(x, top_margin), Vector2(tree_w, tree_h))
		card.pressed.connect(_on_tree_selected.bind(i))
		container.add_child(card)

		var icon_path: String = SKILL_TREE_ICONS[i]
		var label_y := tree_h - 56.0
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			# На всю карточку, вплоть до искажения пропорций — просили
			# растянуть, а не вписать с сохранением пропорций
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			# Без этого TextureRect держит минимальным размером натуральный
			# размер текстуры (512×512) и Control.size молча подтягивает
			# запрошенный размер обратно до него
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.position = Vector2.ZERO
			icon.size = Vector2(tree_w, tree_h)
			# Полупрозрачная — фон под подписью, а не самостоятельная картинка
			icon.modulate = Color(1, 1, 1, 0.3)
			card.add_child(icon)

		var label := _make_label(SKILL_TREE_NAMES[i], 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, label_y)
		label.size = Vector2(tree_w, 32)
		label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)

	return container


func _on_tree_selected(index: int) -> void:
	_play_ui_sound(SOUND_CHOICE)
	_skill_tree_selector.visible = false
	_skills_back_btn.visible = false  # свой "← К ДЕРЕВЬЯМ" ниже вместо него

	var sz := _detail_frame_size()
	_resize_skills_frame(sz.x, sz.y)

	for c in _skill_tree_detail.get_children():
		c.queue_free()

	# Только Руны Стойкости (index 0) реально реализованы — у остальных
	# в SkillTrees.gd пустой nodes[], им и положена заглушка, как раньше
	if index == 0 and is_instance_valid(_player):
		var tree_panel := SkillTreePanelScript.new()
		tree_panel.position = Vector2(0, 44)
		tree_panel.size = Vector2(_skills_pw, _skills_ph - 130.0)
		_skill_tree_detail.add_child(tree_panel)
		tree_panel.init(SkillTrees.RUNES_OF_ENDURANCE, _player)
	else:
		var tree_name: String = SKILL_TREE_NAMES[index]

		var title := _make_label(tree_name, 24)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.position = Vector2(0, _skills_ph / 2.0 - 40.0)
		title.size = Vector2(_skills_pw, 32)
		title.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
		_skill_tree_detail.add_child(title)

		var hint := _make_label("Древо навыков в разработке", 15)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.position = Vector2(0, _skills_ph / 2.0)
		hint.size = Vector2(_skills_pw, 22)
		hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_skill_tree_detail.add_child(hint)

	var back := _make_button("←  К ДЕРЕВЬЯМ", Vector2((_skills_pw - 220.0) / 2.0, _skills_ph - 76.0), Vector2(220, 44))
	back.pressed.connect(_on_tree_detail_back)
	_skill_tree_detail.add_child(back)

	_skill_tree_detail.visible = true


func _on_tree_detail_back() -> void:
	_play_ui_sound(SOUND_CHOICE)
	_skill_tree_detail.visible = false
	_skill_tree_selector.visible = true
	_skills_back_btn.visible = true
	var sz := _selector_frame_size()
	_resize_skills_frame(sz.x, sz.y)


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

## Разделитель — линия, гаснущая к обоим концам, а не сплошная полоса
func _add_divider(parent: Control, pos: Vector2, width: float) -> Control:
	var d := _make_fade_line(width, false, COLOR_DIVIDER)
	d.position = pos
	parent.add_child(d)
	return d


## Окно с орнаментной рамкой. Им же рисуется окно "НАВЫКИ" — чтобы все
## разделы инвентаря выглядели одинаково
func _make_panel(pos: Vector2, sz: Vector2) -> Control:
	var c := _make_frame()
	c.position = pos
	c.size = sz
	c.set("fill_color", COLOR_FRAME_FILL)
	c.set("double_border", true)
	c.set("corner_length", 30.0)
	c.set("corner_width", 2.0)
	return c


func _make_frame() -> Control:
	var f := Control.new()
	f.set_script(OrnateFrameScript)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _make_diamond(d: float) -> Control:
	var m := Control.new()
	m.set_script(DiamondMarkerScript)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(d, d)
	return m


func _make_glyph(glyph: String, color: Color, d: float) -> Control:
	var g := Control.new()
	g.set_script(GlyphIconScript)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size = Vector2(d, d)
	g.call("set_glyph", glyph, color)
	return g


## Линия, гаснущая к обоим концам (прозрачный → цвет → цвет → прозрачный)
func _make_fade_line(length: float, vertical: bool, color: Color, thickness := 1.0) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4 if vertical else 64
	tex.height = 64 if vertical else 4
	tex.fill_from = Vector2(0.5, 0.0) if vertical else Vector2(0.0, 0.5)
	tex.fill_to = Vector2(0.5, 1.0) if vertical else Vector2(1.0, 0.5)

	var line := TextureRect.new()
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(thickness, length) if vertical else Vector2(length, thickness)
	return line


## Радиальное пятно-градиент, растянутое на rect (в прямоугольнике — эллипс)
func _make_radial(rect: Rect2, offsets: PackedFloat32Array, colors: PackedColorArray) -> TextureRect:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return _texture_rect(tex, rect)


func _make_linear(rect: Rect2, from: Color, to: Color, vertical: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([from, to])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4 if vertical else 64
	tex.height = 64 if vertical else 4
	tex.fill_from = Vector2(0.5, 0.0) if vertical else Vector2(0.0, 0.5)
	tex.fill_to = Vector2(0.5, 1.0) if vertical else Vector2(1.0, 0.5)
	return _texture_rect(tex, rect)


func _texture_rect(tex: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = rect.position
	t.size = rect.size
	return t


func _flat_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	return lbl


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz

	# Прямые углы и тонкая золотая кайма — в тон орнаментным рамкам
	btn.add_theme_stylebox_override("normal",   _flat_box(Color(0.07, 0.06, 0.05, 0.92), COLOR_BORDER))
	btn.add_theme_stylebox_override("hover",    _flat_box(Color(0.14, 0.105, 0.065, 0.95), COLOR_BORDER_HI))
	btn.add_theme_stylebox_override("pressed",  _flat_box(Color(0.05, 0.04, 0.03, 0.95), COLOR_BORDER))
	btn.add_theme_stylebox_override("disabled", _flat_box(Color(0.06, 0.055, 0.05, 0.8), Color(0.3, 0.27, 0.22, 0.6)))
	btn.add_theme_color_override("font_color",          COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color",    COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	btn.add_theme_font_size_override("font_size", 15)
	return btn
