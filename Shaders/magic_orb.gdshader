shader_type canvas_item;
render_mode blend_add, unshaded;
// Огненный шар мага в полёте. Рисуется на вытянутом прямоугольнике, который
// повёрнут по направлению полёта (Player_scene/mage_fireball.gd): шар у
// правого края, хвост пламени уходит влево. Слои:
//   ядро     — почти белое, слегка пульсирует;
//   плазма   — клубящийся синий шар с рваной кромкой (шум по углу, вращается);
//   хвост    — языки пламени, сужаются и рвутся к концу;
//   ореол    — мягкое свечение вокруг.

uniform vec4 color_core : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec4 color_mid : source_color = vec4(0.42, 0.72, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.12, 0.3, 1.0, 1.0);
// Размер прямоугольника в px мира — по нему считаются радиусы
uniform vec2 size = vec2(84.0, 40.0);
// Где центр шара (доля длины от левого края)
uniform float orb_x = 0.68;
uniform float radius = 6.5;
uniform float tail_length = 44.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

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

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.1;
}

void fragment() {
	// Координаты в px мира, центр — шар
	vec2 p = (UV - vec2(orb_x, 0.5)) * size;
	float d = length(p);
	float t = TIME + seed;

	// Ядро: пульсирует
	float pulse = 0.9 + 0.1 * sin(t * 23.0);
	float core = 1.0 - smoothstep(0.0, radius * 0.55 * pulse, d);

	// Плазма: кромка шара рвётся шумом по углу, узор вращается
	float ang = atan(p.y, p.x);
	float swirl = fbm(vec2(ang * 1.6 + t * 5.0, d * 0.35 - t * 7.0));
	float edge_r = radius * (1.0 + (swirl - 0.5) * 0.7);
	float body = 1.0 - smoothstep(edge_r - 2.0, edge_r + 1.5, d);
	float veins = smoothstep(0.45, 0.85, fbm(vec2(ang * 3.0 - t * 9.0, d * 0.6 + t * 4.0)));

	// Хвост: позади шара (p.x < 0), сужается к концу, языки рвутся и бегут назад
	float tail = 0.0;
	if (p.x < radius * 0.5) {
		float k = clamp(-p.x / tail_length, 0.0, 1.0);
		float w = radius * (1.0 - k) * 1.05;
		float flame = fbm(vec2(p.x * 0.18 + t * 16.0, p.y * 0.35 + seed));
		float jag = w * (0.55 + 0.75 * flame);
		tail = (1.0 - smoothstep(jag * 0.4, jag, abs(p.y + (flame - 0.5) * 3.0 * k)));
		tail *= (1.0 - smoothstep(0.55, 1.0, k)) * smoothstep(-1.0, 0.15, -k + 1.0);
		tail *= 0.55 + 0.45 * smoothstep(0.3, 0.75, flame);
	}

	// Ореол
	float halo = exp(-d * d / (radius * radius * 4.0)) * 0.5;

	float a = core * 1.2 + body * (0.65 + 0.35 * veins) + tail * 0.75 + halo;
	vec3 col = color_edge.rgb;
	col = mix(col, color_mid.rgb, clamp(body * 0.8 + tail * 0.5 + veins * body * 0.3, 0.0, 1.0));
	col = mix(col, color_core.rgb, clamp(core + veins * body * 0.25, 0.0, 1.0));
	// Ореол мягко гаснет к краям прямоугольника — без видимой рамки
	a *= smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x))
			* smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y));
	COLOR = vec4(col, clamp(a * intensity, 0.0, 1.0));
}
