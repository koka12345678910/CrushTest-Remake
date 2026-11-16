shader_type canvas_item;
// Дно пропасти/оврага далеко внизу: каменистая земля, которая при беге вдоль
// обрыва «отстаёт» — сдвигается медленнее земли наверху (параллакс < 1).
// Фрагмент на поверхности в точке W показывает точку дна D = C + (W − C)/k,
// где C — центр камеры (cam_pos, его каждый кадр пишет immersion.gd).
// Видно только внутри маски пустоты; у стен темнее — дно уходит в тень.

uniform sampler2DArray ground_layers : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask : filter_linear;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 area = vec4(0.0, 0.0, 1024.0, 1024.0);
uniform vec2 cam_pos = vec2(0.0);
// Глубина: 1 — как земля, меньше — дальше
uniform float parallax = 0.72;
// Слои земли: камни и мокрая земля (см. tools/build_terrain.gd)
uniform float layer_a = 3.0;
uniform float layer_b = 5.0;
uniform float tile_world = 150.0;
// Яркость дна и насколько темнеют края у стен
uniform float floor_light = 0.55;
uniform float edge_dark = 1.6;
uniform vec3 tint : source_color = vec3(0.75, 0.8, 0.95);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 muv = (world_pos - area.xy) / area.zw;
	float m = texture(mask, muv).r;
	if (m < 0.003) {
		discard;
	}
	vec2 d = cam_pos + (world_pos - cam_pos) / parallax;
	vec2 uv = d / tile_world;
	vec3 a = texture(ground_layers, vec3(uv, layer_a)).rgb;
	vec3 b = texture(ground_layers, vec3(uv * 0.83 + vec2(0.31, 0.17), layer_b)).rgb;
	float k = texture(noise, d / 900.0).r;
	vec3 col = mix(a, b, smoothstep(0.35, 0.65, k));
	// Свет падает сверху только в середину расщелины
	float light = pow(clamp(m, 0.0, 1.0), edge_dark) * floor_light;
	COLOR = vec4(col * tint * light, m);
}
