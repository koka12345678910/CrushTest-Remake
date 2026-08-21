extends Node2D
## Всплеск капли дождя о землю — по образцу blood_vfx.gd: проигрывает
## анимацию один раз и уничтожает себя. Три варианта листа (dry_drop1,
## dry_drop2, rain_ping) выбираются случайно при каждом спавне — чтобы
## одинаковые всплески не примелькались, как и в остальных пулах в этом
## проекте (звуки ударов, шаги)

const ANIMATIONS := ["splash_1", "splash_2", "splash_3"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	scale *= randf_range(0.7, 1.15)   # разброс размера — капли не одинаковые
	sprite.play(ANIMATIONS.pick_random())

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
