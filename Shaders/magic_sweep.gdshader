shader_type canvas_item;
render_mode blend_add, unshaded;
// Пелена магии для ближней атаки мага (Attack_2_). Рисуется на дуге-
// полумесяце (меш собирает Player_scene/mage_sweep.gd):
//   UV.x — вдоль дуги: 0 хвост (откуда пошла рука) .. 1 голова (куда ушла)
//   UV.y — поперёк: 0 внутренний край .. 1 внешний
// progress (0..1) — где сейчас голова потока: дуга "прорисовывается" за
// рукой; fade (1..0) — общее угасание после взмаха.

uniform vec4 color_core : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.15, 0.45, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Длина светящегося хвоста за головой (в долях дуги)
uniform float tail_length = 0.75;
uniform float intensity = 1.6;

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
	// Видна только уже пройденная рукой часть дуги
	float behind = progress - x;
	if (behind < 0.0) {
		discard;
	}
	// Яркий край у головы, к хвосту тает
	float tail = 1.0 - smoothstep(0.0, tail_length, behind);
	float head = smoothstep(0.12, 0.0, behind);
	// Поперечный профиль: плотная середина, мягкие края
	float band = smoothstep(0.0, 0.35, y) * (1.0 - smoothstep(0.7, 1.0, y));
	// Прожилки магии: вытянуты вдоль дуги и текут к хвосту
	float streak = noise(vec2(x * 6.0 - TIME * 3.0, y * 9.0));
	streak = smoothstep(0.35, 0.9, streak * 0.75 + noise(vec2(x * 14.0, y * 22.0 + TIME)) * 0.35);
	float a = band * (tail * (0.45 + 0.55 * streak) + head * 0.9) * fade * intensity;
	vec3 col = mix(color_edge.rgb, color_core.rgb, clamp(head + streak * 0.4 * tail, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
