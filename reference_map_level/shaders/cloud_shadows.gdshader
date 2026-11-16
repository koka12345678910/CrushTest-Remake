shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// Облака у луны: огромные мягкие пятна ползут по карте. Под облаком всё
// (земля, крыши, кроны) притемняется, в просветах — чуть холодного лунного
// света. Одним проходом: premultiplied alpha = фон·(1 − тень) + лунный свет.
// Ночной CanvasModulate не трогает (unshaded). Где светло от факелов и
// костров, эффект слабеет: облако гасит луну, а не огонь.
// Узел — reference_map_level/scripts/immersion.gd (_build_clouds).

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

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	COLOR = vec4(moon, shade);
}
