shader_type canvas_item;
render_mode blend_add, unshaded;
// Рунический круг под магом при импульсе (Attack_3_). Квадрат, центр — маг;
// по вертикали узел сплюснут (круг лежит на земле). Слои:
//   два тонких кольца, между ними — пояс "рун": короткие засечки и знаки,
//   медленно вращается; внутри — звезда из линий; всё дрожит и тает по fade.

uniform vec4 color_core : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.2, 0.45, 1.0, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// 0..1 — круг "прорисовывается" по окружности
uniform float draw : hint_range(0.0, 1.0) = 1.0;
uniform float spin = 0.6;
uniform float seed = 0.0;
uniform float intensity = 1.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed) * 43758.5453);
}

float line_seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - smoothstep(0.0, w, length(pa - ba * h));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) + TIME * spin;
	float a01 = fract(ang / 6.28318 + 1.0);
	// Прорисовка по кругу
	float drawn = step(a01, draw);

	float w = 0.012;
	float ring1 = 1.0 - smoothstep(0.0, w, abs(r - 0.94));
	float ring2 = 1.0 - smoothstep(0.0, w, abs(r - 0.78));
	float ring3 = 1.0 - smoothstep(0.0, w * 0.8, abs(r - 0.42));

	// Пояс рун: 24 ячейки по кругу, в каждой — засечка или знак
	float cells = 24.0;
	float ci = floor(a01 * cells);
	float cf = fract(a01 * cells);
	float rn = hash(ci);
	float band = step(0.8, r) * step(r, 0.92);
	float y = (r - 0.8) / 0.12;
	float glyph = 0.0;
	if (rn < 0.33) {
		glyph = (1.0 - smoothstep(0.0, 0.08, abs(cf - 0.5))) * step(0.15, y) * step(y, 0.85);
	} else if (rn < 0.66) {
		glyph = (1.0 - smoothstep(0.0, 0.07, abs(cf - y))) * step(0.1, y) * step(y, 0.9);
		glyph = max(glyph, (1.0 - smoothstep(0.0, 0.07, abs(cf - 0.5))) * step(0.5, y) * step(y, 0.9));
	} else {
		glyph = (1.0 - smoothstep(0.0, 0.1, abs(y - 0.5))) * step(0.25, cf) * step(cf, 0.75);
	}
	glyph *= band;

	// Звезда внутри: шесть линий через центр, повёрнута в другую сторону
	vec2 q = p;
	float star = 0.0;
	for (int i = 0; i < 3; i++) {
		float an = float(i) * 2.0944 - TIME * spin * 0.7;
		vec2 a = vec2(cos(an), sin(an)) * 0.76;
		vec2 b = vec2(cos(an + 2.0944), sin(an + 2.0944)) * 0.76;
		star = max(star, line_seg(q, a, b, 0.012));
		vec2 c = vec2(cos(an + 1.0472), sin(an + 1.0472)) * 0.76;
		vec2 d = vec2(cos(an + 3.1416), sin(an + 3.1416)) * 0.76;
		star = max(star, line_seg(q, c, d, 0.012));
	}
	star *= step(r, 0.78);

	float glow = exp(-pow((r - 0.86) * 9.0, 2.0)) * 0.35;
	float flicker = 0.85 + 0.15 * sin(TIME * 30.0 + seed);
	float a = (ring1 + ring2 * 0.8 + ring3 * 0.6 + glyph + star * 0.6) * drawn + glow;
	a *= fade * flicker * intensity * (1.0 - smoothstep(0.97, 1.0, r));
	vec3 col = mix(color_edge.rgb, color_core.rgb, clamp(ring1 + glyph * 0.7, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
