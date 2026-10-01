shader_type canvas_item;

#include "res://Shaders/occlusion_fade.gdshaderinc"

uniform float amplitude : hint_range(0.0, 20.0) = 3.0;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
uniform float wind_dir : hint_range(-1.0, 1.0) = 1.0;
uniform float variation : hint_range(0.0, 1.0) = 0.02;
// Прозрачное окно вокруг игрока (occlusion_fade.gdshaderinc). Включать только
// слоям, которые рисуются ПОВЕРХ персонажа (трава TileMap_Plant) — слой Forest
// лежит под ним, ему окно ни к чему
uniform bool occlusion_enabled = false;

void vertex() {
	float phase = TIME * speed + (VERTEX.x + VERTEX.y) * variation;
	float sway = sin(phase) * amplitude * (1.0 - UV.y);
	VERTEX.x += sway * wind_dir;
	occlusion_world_pos = occlusion_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= object_brightness;
	if (occlusion_enabled) {
		COLOR.a *= occlusion_alpha(occlusion_world_pos);
	}
}
