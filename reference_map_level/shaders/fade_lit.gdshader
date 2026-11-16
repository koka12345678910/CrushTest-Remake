shader_type canvas_item;
// Shaders/occlusion_fade_plain.gdshader + свет по карте нормалей.
// scripts/normal_maps.gd ставит этот шейдер общему материалу OcclusionFade
// (только на reference_map; сам occlusion_fade_plain не тронут).

#include "res://Shaders/occlusion_fade.gdshaderinc"
#include "res://reference_map_level/shaders/normal_light.gdshaderinc"

void vertex() {
	occlusion_world_pos = occlusion_world(VERTEX, MODEL_MATRIX);
	occlusion_origin = occlusion_world(vec2(0.0), MODEL_MATRIX);
}

void fragment() {
	COLOR.rgb *= object_brightness;
	COLOR.a *= occlusion_alpha_depth(occlusion_world_pos, occlusion_origin);
}
