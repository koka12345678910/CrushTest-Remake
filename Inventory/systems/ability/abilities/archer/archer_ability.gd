# res://Inventory/systems/ability/abilities/archer/archer_ability.gd
class_name ArcherAbility
extends Ability
## Общая база предметов лучницы. Сам эффект живёт в archer.gd — там стрелы,
## криты и метки, — а предмет только говорит "включи навык skill_id". Так
## механику можно крутить в одном месте, не бегая по девяти файлам.

## Ключ навыка для archer.gd::activate_archer_skill()
var skill_id := ""
## Длительность для временных навыков (0 — навык заряжает стрелы, а не таймер)
var duration := 0.0
## Сколько следующих стрел заряжает навык (Коготь Фенрира, Шёпот Одина)
var shots := 0

const SOUND_RUNE := preload("res://Sound/abilities_sound/rune_sound.mp3")
const SOUND_EYE := preload("res://Sound/abilities_sound/eye_amulet_sound.mp3")
var activation_sound: AudioStream = SOUND_RUNE


func _execute(player: Node) -> void:
	if not player.has_method("activate_archer_skill"):
		push_warning("[%s] доступно только лучнице" % ability_name)
		return
	player.activate_archer_skill(skill_id, self)
