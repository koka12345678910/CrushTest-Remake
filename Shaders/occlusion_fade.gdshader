shader_type canvas_item;
// Прозрачное окно вокруг игрока для всего, что его перекрывает
// (TileMap_Props, магазин). Логика — в occlusion_fade.gdshaderinc

#include "res://Shaders/occlusion_fade.gdshaderinc"

void vertex() {
	occlusion_world_pos = occlusion_world(VERTEX, MODEL_MATRIX);
	occlusion_origin = occlusion_world(vec2(0.0), MODEL_MATRIX);
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= object_brightness;
	COLOR.a *= occlusion_alpha_depth(occlusion_world_pos, occlusion_origin);
}
