shader_type canvas_item;
// Под кронами темнее: земля в густом лесу в тени, сквозь листву пробиваются
// пятна лунного света, которые шевелит ветер. Рисуется под объектами
// (деревья, герой — поверх). Маска — где стоят деревья, тексель = cell px.
// Узел — immersion.gd (_build_canopy).

uniform sampler2D mask : filter_linear;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 area = vec4(0.0, 0.0, 1024.0, 1024.0);
uniform float strength = 0.45;
// Размер пятен света (мировые px) и как сильно они пробивают тень
uniform float dapple_scale = 70.0;
uniform float dapple = 0.65;
uniform float wind_strength = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 muv = (world_pos - area.xy) / area.zw;
	float m = texture(mask, muv).r;
	if (m < 0.01) {
		discard;
	}
	float t = TIME;
	// Листва качается: пятна дрожат на месте, а не уплывают
	vec2 sway = vec2(sin(t * 0.7 + world_pos.y * 0.01), cos(t * 0.53 + world_pos.x * 0.012)) * 4.0 * wind_strength;
	float n = texture(noise, (world_pos + sway) / dapple_scale).r * 0.7
		+ texture(noise, (world_pos - sway * 1.7) / (dapple_scale * 0.45) + vec2(0.3, 0.6)).r * 0.3;
	float holes = smoothstep(0.58, 0.68, n) * dapple;
	COLOR = vec4(0.0, 0.0, 0.0, m * strength * (1.0 - holes));
}
