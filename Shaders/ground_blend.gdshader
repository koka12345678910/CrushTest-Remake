shader_type canvas_item;
// Земля карты (tools/graveyard_generator.gd, build_ground): три бесшовные
// текстуры — трава, утоптанная земля троп и каменистая земля площадок — и
// маска троп/площадок (1 тексель на 8 px мира, R — земля, G — камень).
// Край троп рваный: маска сдвигается шумом, на самой границе чуть темнее —
// как обводка у нарисованных квадратов земли в листе.

uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear;
uniform sampler2D stone_tex : source_color, repeat_enable, filter_linear;
uniform sampler2D mask_tex : filter_linear;
// Размер карты в px мира (маска растянута на неё целиком)
uniform vec2 map_px = vec2(3072.0, 1536.0);
// Сколько px мира занимает один повтор текстур
uniform float tex_world = 430.0;
uniform float edge_noise = 0.3;
uniform float edge_dark = 0.35;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

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

void fragment() {
	vec2 uv = world_pos / tex_world;
	vec3 g = texture(grass_tex, uv).rgb;
	vec3 d = texture(dirt_tex, uv + vec2(0.37, 0.11)).rgb;
	vec3 s = texture(stone_tex, uv + vec2(0.71, 0.53)).rgb;
	vec2 m = texture(mask_tex, world_pos / map_px).rg;
	float n = noise(world_pos / 11.0) * 0.6 + noise(world_pos / 4.0) * 0.4 - 0.5;
	float dm = smoothstep(0.4, 0.6, m.r + n * edge_noise);
	float sm = smoothstep(0.4, 0.6, m.g + n * edge_noise);
	vec3 c = mix(g, d, dm);
	c = mix(c, s, sm);
	// Тёмная кромка на границе травы и земли
	float edge = 4.0 * dm * (1.0 - dm);
	c *= 1.0 - edge * edge_dark;
	// COLOR на входе — цвет полигона (общее затемнение под ночь)
	COLOR = vec4(c, 1.0) * COLOR;
}
