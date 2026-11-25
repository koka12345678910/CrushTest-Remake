shader_type canvas_item;
render_mode blend_add;

// Пламя костра в меню — маленькое, низкое, живое. Рисуется сложением поверх
// нарисованного огня у основания меча (bg_front.png), несколькими языками
// (MenuBackdrop.gd ставит 5 прямоугольников с разным seed и размером).
//
// Форма — капля: широкая у углей, к верху сходится в тонкий язык. Края
// мягкие; три октавы шума, бегущего вверх, изгибают язык, рвут его высоту и
// выедают «дыры» в верхней части — пламя распадается на отдельные всполохи,
// а не стоит сплошным треугольником. Цвет — по «температуре»: у углей и в
// плотной части жёлто-белый, выше оранжевый, кончики тёмно-красные и
// полупрозрачные.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float intensity = 1.0;
uniform float seed = 0.0;
// Ширина пламени у основания (доля ширины прямоугольника, 0..0.5)
uniform float base_width = 0.36;
// Скорость подъёма шума
uniform float rise = 0.85;

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;          // 0 — угли, 1 — верх прямоугольника
	float x = uv.x - 0.5;
	float t = TIME * rise + seed * 7.31;

	float n1 = texture(noise_tex, vec2(uv.x * 1.3 + seed, uv.y * 1.0 + t)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 3.2 + seed * 2.3, uv.y * 2.6 + t * 1.8)).r;
	float n3 = texture(noise_tex, vec2(uv.x * 6.0 + seed * 3.7, uv.y * 5.0 + t * 2.6)).r;
	float n = n1 * 0.55 + n2 * 0.3 + n3 * 0.15;

	// Язык извивается тем сильнее, чем выше
	float xd = x + (n1 - 0.5) * 0.34 * y + (n2 - 0.5) * 0.12 * y;
	float width = mix(base_width, 0.02, pow(y, 0.65));
	float shape = 1.0 - smoothstep(width * 0.15, width, abs(xd));
	// Высота рвётся шумом: то вытягивается, то опадает
	float h = y + (n - 0.5) * 0.7;
	float body = shape * (1.0 - smoothstep(0.15, 0.85, h));
	// Наверху мелкий шум выедает дыры — отрываются отдельные всполохи
	body *= smoothstep(0.0, 0.35, n2 + n3 * 0.5 - y * 0.55 + 0.25);
	// У самого низа — мягко, без обреза по краю прямоугольника
	body *= smoothstep(0.0, 0.12, y);

	float temp = clamp(body * (1.3 - y * 0.9), 0.0, 1.0);
	vec3 col = mix(vec3(0.55, 0.06, 0.01), vec3(1.0, 0.42, 0.06), smoothstep(0.1, 0.55, temp));
	col = mix(col, vec3(1.0, 0.84, 0.5), smoothstep(0.62, 0.97, temp));
	float a = smoothstep(0.02, 0.5, body);
	COLOR = vec4(col * intensity, a * 0.92);
}
