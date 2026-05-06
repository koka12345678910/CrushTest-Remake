# ============================================================
# ДОБАВЬ ЭТО В player.gd
# ============================================================
# 1. @onready — добавь к существующим @onready в самом верху:

@onready var health_bar = $HealthStaminaBar  # CanvasLayer нода


# ============================================================
# 2. ПЕРЕМЕННЫЕ — добавь к существующим переменным:

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0


# ============================================================
# 3. В _ready() — добавь в конец существующей функции:

func _ready() -> void:
	# ... твой существующий код ...

	# HP и стамина
	health_bar.set_max_hp(max_health)
	health_bar.set_max_stamina(max_stamina)


# ============================================================
# 4. МЕТОДЫ — замени существующий take_damage и heal,
#    или добавь если их нет:

func take_damage(amount: int) -> void:
	health_bar.take_damage(float(amount))
	health = health_bar.current_hp
	print("[Player] HP: %.0f / %.0f" % [health, max_health])
	if not health_bar.is_alive():
		print("[Player] Погиб!")
		# TODO: вызов death когда будет готово


func heal(amount: float) -> void:
	health_bar.heal(amount)
	health = health_bar.current_hp
	print("[Player] Лечение: %.0f HP" % amount)


func use_stamina(amount: float) -> bool:
	var ok := health_bar.use_stamina(amount)
	stamina = health_bar.current_stamina
	return ok


# ============================================================
# 5. ИСПОЛЬЗОВАНИЕ СТАМИНЫ — пример в dodge/roll:
# В start_dodge() добавь в начало:
#
#   if not use_stamina(20.0):
#       return   # не хватает стамины — не додживаем
#
# В start_roll():
#   if not use_stamina(30.0):
#       return
#
# В play_attack() — по желанию:
#   use_stamina(10.0)
