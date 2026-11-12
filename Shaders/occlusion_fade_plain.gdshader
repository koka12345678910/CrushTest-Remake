shader_type canvas_item;
// То же окно прозрачности вокруг героя, что occlusion_fade.gdshader, но цвет
// предмета остаётся ровно как нарисован.
//
// В Godot 4 COLOR во fragment() уже содержит цвет текстуры, умноженный на
// modulate. occlusion_fade.gdshader умножает его на texture(TEXTURE, UV) ещё
// раз — цвет возводится в квадрат (темнее и контрастнее), и материалы кладбища
// подобраны под это (object_brightness 1.15–1.7). Присланные карты
// (reference_map) нарисованы под обычный вывод — им нужен этот вариант.
// Логика окна — в occlusion_fade.gdshaderinc

#include "res://Shaders/occlusion_fade.gdshaderinc"

void vertex() {
	occlusion_world_pos = occlusion_world(VERTEX, MODEL_MATRIX);
	occlusion_origin = occlusion_world(vec2(0.0), MODEL_MATRIX);
}

void fragment() {
	COLOR.rgb *= object_brightness;
	COLOR.a *= occlusion_alpha_depth(occlusion_world_pos, occlusion_origin);
}
