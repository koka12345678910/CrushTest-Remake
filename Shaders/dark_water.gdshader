shader_type canvas_item;
// Тёмная стоячая вода (пруд): почти чёрная гладь с медленной рябью и
// редкими бликами. Цвет задаёт сам полигон (Polygon2D.color), освещение —
// как у остальной сцены, поэтому факелы у берега дают на воде отсвет.

uniform vec4 deep_color : source_color = vec4(0.07, 0.11, 0.13, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.22, 0.24, 1.0);
uniform vec4 glint_color : source_color = vec4(0.55, 0.65, 0.7, 1.0);
uniform float ripple_scale = 0.06;
uniform float ripple_speed = 0.6;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos * ripple_scale;
	float r = noise(p + vec2(TIME * ripple_speed, 0.0)) * 0.6
			+ noise(p * 2.7 - vec2(0.0, TIME * ripple_speed * 1.3)) * 0.4;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, r * 0.6);
	// Редкие блики — только на гребнях ряби
	float glint = smoothstep(0.82, 0.95, r);
	col = mix(col, glint_color.rgb, glint * 0.35);
	COLOR = vec4(col, 1.0) * COLOR;
}
