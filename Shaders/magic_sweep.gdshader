shader_type canvas_item;
render_mode blend_add, unshaded;
// Пелена магии для ближней атаки мага (Attack_2_). Рисуется на дуге-
// полумесяце (меш собирает Player_scene/mage_sweep.gd):
//   UV.x — вдоль дуги: 0 хвост (откуда пошла рука) .. 1 голова (куда ушла)
//   UV.y — поперёк: 0 внутренний край .. 1 внешний
// progress (0..1) — где сейчас голова потока: дуга "прорисовывается" за
// рукой; fade (1..0) — общее угасание после взмаха.
// Слои: мягкая пелена, тонкие яркие нити энергии вдоль дуги, искрящаяся
// внешняя кромка, раскалённая голова потока и блёстки.

uniform vec4 color_core : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform vec4 color_mid : source_color = vec4(0.42, 0.72, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.15, 0.4, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Длина светящегося хвоста за головой (в долях дуги)
uniform float tail_length = 0.75;
uniform float intensity = 1.6;
uniform float seed = 0.0;

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
	float x = UV.x;
	float y = UV.y;
	float t = TIME + seed;
	// Видна только уже пройденная рукой часть дуги
	float behind = progress - x;
	if (behind < 0.0) {
		discard;
	}
	float tail = 1.0 - smoothstep(0.0, tail_length, behind);
	// Голова потока: передний край не обрезан прямо, а мягко нарастает
	float head = smoothstep(0.16, 0.02, behind) * smoothstep(0.0, 0.035, behind);

	// Пелена: плотная середина, мягкие края, рваная внешняя граница
	float rag = noise(vec2(x * 18.0 - t * 4.0, 3.0)) * 0.18;
	float band = smoothstep(0.0, 0.3, y) * (1.0 - smoothstep(0.62 - rag, 0.98 - rag, y));
	float flow = noise(vec2(x * 6.0 - t * 3.0, y * 9.0));
	flow = smoothstep(0.3, 0.9, flow * 0.7 + noise(vec2(x * 14.0, y * 22.0 + t)) * 0.4);

	// Нити энергии: тонкие синусы поперёк, слегка гуляют вдоль дуги
	float fil = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float yy = 0.3 + fi * 0.18 + sin(x * (9.0 + fi * 4.0) - t * (7.0 + fi * 2.0) + fi * 2.1) * 0.05;
		fil = max(fil, 1.0 - smoothstep(0.0, 0.025, abs(y - yy)));
	}
	fil *= tail * smoothstep(0.0, 0.05, behind + 0.02);

	// Искрящаяся внешняя кромка
	float rim = (1.0 - smoothstep(0.0, 0.06, abs(y - (0.84 - rag)))) * tail;
	rim *= 0.5 + 0.5 * noise(vec2(x * 40.0 - t * 10.0, 1.0));

	// Блёстки: редкие яркие точки, мигают
	vec2 sp = vec2(x * 60.0, y * 10.0);
	float sparkle = step(0.965, hash(floor(sp) + floor(t * 12.0))) * band * tail;

	float a = band * (tail * (0.35 + 0.45 * flow) + head * 0.6)
			+ fil * 0.75 + rim * 0.6 + sparkle * 1.2;
	// Концы дуги и передний край головы сходят на нет — без прямого среза
	a *= smoothstep(0.0, 0.08, x) * (1.0 - smoothstep(0.86, 1.0, x)) * smoothstep(0.0, 0.03, behind);
	a *= fade * intensity;
	vec3 col = mix(color_edge.rgb, color_mid.rgb, clamp(flow * tail + rim, 0.0, 1.0));
	col = mix(col, color_core.rgb, clamp(head + fil * 0.8 + sparkle, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
