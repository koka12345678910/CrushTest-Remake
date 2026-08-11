extends Node
## GameSettings.gd — глобальные настройки игры (автозагрузка).
##
## Хранит значения, сохраняет их в user://settings.cfg и применяет к движку.
## Панель настроек (SettingsPanel.gd) только читает и пишет эти значения —
## применением занимается ТОЛЬКО этот скрипт. Так одни и те же настройки
## работают из любого места (главное меню, будущее меню паузы) и переживают
## перезапуск игры.

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"

# --- Звук: храним 0..1 (так удобнее для слайдеров), в дБ переводим при
# применении. Логарифмический перевод (linear_to_db) обязателен: если
# крутить дБ линейно, середина ползунка звучит почти как максимум
var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8

# --- Геймплей ---
# У этой игры тряски камеры много (удары, стан, истощение, парирование), и
# для части игроков это некомфортно вплоть до укачивания. 0 = выключить совсем
var shake_multiplier := 1.0

# --- Экран ---
var fullscreen := false
var vsync := true

# Имена шин из default_bus_layout.tres. "Combat" держит боевые SFX, музыка
# живёт на своей шине, остальное (шаги, эмбиент) идёт напрямую в Master и
# регулируется общим ползунком
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "Combat"
const SILENT_DB := -80.0


func _ready() -> void:
	load_settings()
	apply_all()


# ----------------------------------------------------------
# ПРИМЕНЕНИЕ
# ----------------------------------------------------------

func apply_all() -> void:
	_apply_bus(BUS_MASTER, master_volume)
	_apply_bus(BUS_MUSIC, music_volume)
	_apply_bus(BUS_SFX, sfx_volume)
	_apply_window()
	settings_changed.emit()


func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, volume_to_db(value))


func _apply_window() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


# 0..1 -> дБ. На нуле уходим в тишину явно: linear_to_db(0) даёт -inf, а это
# ломает твины и сериализацию
static func volume_to_db(value: float) -> float:
	if value <= 0.001:
		return SILENT_DB
	return linear_to_db(clampf(value, 0.0, 1.0))


# Базовый уровень музыки — его спрашивает level_music_manager, чтобы даккинг
# проседал ОТНОСИТЕЛЬНО настройки игрока, а не возвращал музыку на 0 дБ,
# затирая выставленную громкость
func get_music_base_db() -> float:
	return volume_to_db(music_volume)


# ----------------------------------------------------------
# СОХРАНЕНИЕ / ЗАГРУЗКА
# ----------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("gameplay", "shake", shake_multiplier)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # файла ещё нет — остаются значения по умолчанию
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	shake_multiplier = cfg.get_value("gameplay", "shake", shake_multiplier)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	vsync = cfg.get_value("display", "vsync", vsync)


func reset_to_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.8
	shake_multiplier = 1.0
	fullscreen = false
	vsync = true
	apply_all()
	save_settings()
