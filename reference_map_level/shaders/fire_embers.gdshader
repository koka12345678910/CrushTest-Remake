shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// Ложе углей под пламенем (reference_map, scripts/fire_fx.gd): мягкий
// эллипс обугленного дерева, в нём тлеют угли — неровные пятна жара и
// тонкие трещины, которые медленно "дышат" (жар перетекает), отдельные
// угольки вспыхивают ярче. Чёрное затемняет землю, светящееся — аддитивно.
// Цвет вершин: r — сид, a — яркость (0.5 — норма).

uniform float glow = 1.0;
uniform float cells = 9.0;     // сколько головешек поперёк
uniform float char_dark = 0.55;

varying vec4 v_data;

void vertex() {
	v_data = COLOR;
}

vec2 h22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h22(i).x, b = h22(i + vec2(1, 0)).x, c = h22(i + vec2(0, 1)).x, d = h22(i + vec2(1, 1)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}

void fragment() {
	float seed = v_data.r * 57.0;
	float fl = clamp(v_data.a * 2.0, 0.5, 1.6);
	vec2 p = (UV - 0.5) * 2.0;
	// Край ложа неровный — не циркульный эллипс
	float ang = atan(p.y, p.x);
	float rim = 0.78 + 0.22 * vnoise(vec2(ang * 2.5 + seed, seed));
	float r = length(p) / rim;
	float ell = 1.0 - smoothstep(0.45, 1.0, r);
	// Головешки (вороной) — трещины между ними
	vec2 g = vec2(UV.x * cells, UV.y * cells * 0.5) + seed;
	g += vec2(vnoise(g * 0.7), vnoise(g * 0.7 + 5.0)) * 0.6;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float d1 = 8.0, d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + h22(gi + o) * 0.85 - gf;
			float d = dot(c, c);
			if (d < d1) { d2 = d1; d1 = d; id = gi + o; }
			else if (d < d2) { d2 = d; }
		}
	}
	float crack = 1.0 - smoothstep(0.0, 0.16, sqrt(d2) - sqrt(d1));
	// Жар: крупные пятна перетекают медленно; трещины светятся только в них
	float heat = fbm(UV * vec2(5.0, 3.0) + vec2(TIME * 0.18, -TIME * 0.12) + seed);
	heat = smoothstep(0.35, 0.8, heat);
	float ember = h22(id).y;
	float pulse = 0.5 + 0.5 * sin(TIME * (0.8 + ember * 2.0) + ember * 40.0);
	float centre = 1.0 - smoothstep(0.0, 0.85, r);
	float hot = crack * heat * 0.75 + smoothstep(0.7, 1.0, ember) * pulse * heat * 0.6;
	hot += heat * centre * 0.25;
	hot *= ell * fl;
	vec3 c = mix(vec3(0.45, 0.05, 0.01), vec3(1.0, 0.38, 0.06), smoothstep(0.15, 0.7, hot));
	c = mix(c, vec3(1.0, 0.72, 0.3), smoothstep(0.7, 1.1, hot));
	vec3 light = c * smoothstep(0.03, 0.5, hot) * glow;
	// Сажа — мягкая, к краю сходит на нет
	float dark = ell * ell * char_dark * (1.0 - smoothstep(0.05, 0.5, hot));
	COLOR = vec4(light, dark);
}
