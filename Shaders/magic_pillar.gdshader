shader_type canvas_item;
render_mode blend_add, unshaded;
// Столп голубого огня (особая атака мага, SpecialAttack_). Квадрат стоит на
// земле: низ UV — ноги врага, верх — макушка столпа. Огонь — два слоя
// бесшовного шума (noise_tex), бегущие вверх с разной скоростью; край
// столпа рвётся шумом на языки, внутри — белое ядро и яркие струи.
// Всего три выборки текстуры на пиксель — на пять столпов сразу хватает с
// запасом.
//   rise — докуда столп вырос (0..1), fade — общая прозрачность,
//   thin — к концу столп сужается, lift — низ отрывается и уходит вверх

uniform vec4 color_core : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 color_mid : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform vec4 color_edge : source_color = vec4(0.1, 0.24, 1.0, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float rise : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float thin : hint_range(0.0, 1.0) = 0.0;
uniform float lift : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
// Высота / ширина квадрата — чтобы клубы шума не вытягивались по вертикали
uniform float aspect = 2.6;
uniform float speed = 1.0;

void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * speed;

	vec2 base = vec2(UV.x * 0.4 + seed, UV.y * 0.4 * aspect);
	float n1 = texture(noise_tex, base + vec2(0.0, t * 0.9)).r;
	float n2 = texture(noise_tex, base * 2.3 + vec2(0.37, t * 1.9)).r;
	float nn = n1 * 0.6 + n2 * 0.4;

	// Огонь гнётся: чем выше, тем сильнее его водит из стороны в сторону
	float sway = (n1 - 0.5) * 0.45 * y;
	float xd = x - sway;

	// Профиль: широкое горячее основание, столб, к верху сужается
	float w = mix(0.6, 0.28, y) * (1.0 - thin * 0.7);
	w += exp(-y * 12.0) * 0.32 * (1.0 - lift);
	float flame = 1.0 - abs(xd) / max(w, 0.001) + (nn - 0.5) * 1.2;

	// Верх рвётся на языки
	float top = rise * 0.9;
	flame = min(flame, (top - y) / 0.3 + (nn - 0.5) * 1.3);
	// Низ: в конце отрывается от земли
	flame = min(flame, (y + 0.12 - lift * 1.1) / 0.15 + (nn - 0.5) * 0.8);

	float a = smoothstep(0.0, 0.3, flame);
	float hot = smoothstep(0.55, 1.1, flame);

	// Яркие струи, бегущие вверх внутри столпа
	float fil = texture(noise_tex, vec2(UV.x * 1.7 + seed * 1.3, UV.y * 0.22 * aspect + t * 2.6)).r;
	fil = smoothstep(0.6, 0.78, fil) * a;

	vec3 col = mix(color_edge.rgb, color_mid.rgb, smoothstep(0.0, 0.6, flame));
	col = mix(col, color_core.rgb, hot);
	col += color_core.rgb * fil * 0.6;

	// Свечение земли у основания
	float ground = exp(-y * 9.0) * (1.0 - smoothstep(0.25, 1.0, abs(x))) * 0.55 * (1.0 - lift) * rise;

	float alpha = a * (0.4 + 0.4 * hot) + fil * 0.35 + ground;
	// Края квадрата мягкие — и у земли тоже, иначе низ столпа срезан линией
	alpha *= smoothstep(0.0, 0.07, y) * (1.0 - smoothstep(0.93, 1.0, y)) * (1.0 - smoothstep(0.9, 1.0, abs(x)));
	COLOR = vec4(col * intensity, clamp(alpha, 0.0, 1.0) * fade);
}
