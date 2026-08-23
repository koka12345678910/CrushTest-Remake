extends Node2D

# Варианты брызга живут прямо в SpriteFrames сцены (blood_vfx.tscn) — их
# заводят руками в редакторе (Animation panel у AnimatedSprite2D), просто
# добавляя новую анимацию с любым именем. Скрипт ничего не генерирует сам —
# только читает список того, что уже есть, и на каждый спавн выбирает
# случайный. Добавить ещё вариант = добавить анимацию в сцене и сохранить,
# без правок кода
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	scale *= randf_range(0.8, 1.2)  # небольшая случайность размера
	rotation = randf_range(0, TAU)   # случайный поворот для разнообразия
	var names := sprite.sprite_frames.get_animation_names()
	sprite.play(names[randi() % names.size()])


func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
