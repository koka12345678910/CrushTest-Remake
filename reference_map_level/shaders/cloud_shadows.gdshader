shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// Облака у луны: огромные мягкие пятна ползут по карте. Под облаком всё
// (земля, крыши, кроны) притемняется, в просветах — чуть холодного лунного
// света. Одним проходом: premultiplied alpha = фон·(1 − тень) + лунный свет.
// Ночной CanvasModulate не трогает (unshaded). Где светло от факелов и
// костров, эффект слабеет: облако гасит луну, а не огонь.
// Узел — reference_map_level/scripts/immersion.gd (_build_clouds).
//
// Ночной цветокор (grade_amount > 0) — в этом же проходе, без отдельного
// слоя и второй копии экрана (отдельный слой стоил ~1.6 мс на GTX 1060):
//   лунное — приглушено и уведено в холодный серебристо-синий, тени синее;
//   огненное (тёплое и светлое) — не трогается, огонь остаётся сочным;
//   края экрана — виньетка.
// Силу цветокора по времени суток ведёт scripts/weather_link.gd.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Мировые px за секунду
uniform vec2 drift = vec2(11.0, 4.0);
// Размер облака, мировые px
uniform float scale = 2400.0;
// Тень под облаком (доля затемнения)
uniform float strength = 0.28;
// Лунный свет в просветах: доля яркости, добавленная к тому, что уже видно
// (умножением, а не ровной подсветкой — чёрное остаётся чёрным)
uniform vec4 moon_color : source_color = vec4(0.55, 0.63, 0.82, 1.0);
uniform float moon_strength = 0.35;
// Доля неба под облаками и мягкость края
uniform float coverage = 0.5;
uniform float softness = 0.22;
// Яркость, с которой эффект начинает слабеть, и где пропадает совсем
uniform vec2 light_keep = vec2(0.16, 0.42);

// Ночной цветокор
uniform float grade_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.42;
uniform vec3 moon_tint : source_color = vec3(0.78, 0.88, 1.08);
uniform vec3 shadow_tint : source_color = vec3(0.7, 0.8, 1.05);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_radius = 0.92;
uniform float vignette_softness = 0.62;
// Экспозиция (адаптация глаза): у яркого огня кадр темнее, в темноте —
// светлее; задаёт scripts/hero_light.gd по свету вокруг героя. Светлое
// (огонь, блики) почти не трогается — не пересвечивается и не сереет
uniform float exposure = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 night_grade(vec3 col, vec2 suv, vec2 px) {
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(exposure, 1.0, smoothstep(0.45, 0.95, luma));
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	// Насколько пиксель освещён огнём: тёплый оттенок и не совсем тёмный
	float warm = clamp((col.r - col.b) * 3.0 - 0.15, 0.0, 1.0) * smoothstep(0.06, 0.3, col.r);
	float lunar = 1.0 - warm;
	col = mix(col, vec3(luma), desaturation * lunar);
	vec3 tint = mix(shadow_tint, moon_tint, smoothstep(0.02, 0.35, luma));
	col *= mix(vec3(1.0), tint, lunar);
	vec2 uv = suv - vec2(0.5);
	uv.x *= px.y / px.x;
	float vig = 1.0 - smoothstep(vignette_radius - vignette_softness, vignette_radius, length(uv));
	return col * mix(1.0 - vignette_strength, 1.0, vig);
}

void fragment() {
	vec2 p = (world_pos - drift * TIME) / scale;
	float n = texture(noise, p).r * 0.65
		+ texture(noise, p * 2.7 + vec2(0.37, 0.71) - drift * TIME * 0.00012).r * 0.35;
	float s = smoothstep(coverage - softness, coverage + softness, n);
	vec3 bg = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(bg, vec3(0.3, 0.59, 0.11));
	float keep = 1.0 - smoothstep(light_keep.x, light_keep.y, lum);
	float shade = s * strength * keep;
	vec3 moon = bg * moon_color.rgb * (1.0 - s) * moon_strength * keep;
	if (grade_amount > 0.001) {
		vec3 c = bg * (1.0 - shade) + moon;
		COLOR = vec4(mix(c, night_grade(c, SCREEN_UV, SCREEN_PIXEL_SIZE), grade_amount), 1.0);
	} else {
		COLOR = vec4(moon, shade);
	}
}
