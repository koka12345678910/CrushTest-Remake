shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// Река живёт: в воде отражается ночное небо с теми же облаками, что ползут
// по карте (shaders/cloud_shadows), — отражение далёкое, поэтому почти не
// сдвигается при беге (параллакс), а по течению бегут лунные блики.
// Яркость добавляется умножением на то, что уже нарисовано (вода не
// светится сама). Узел — immersion.gd (_build_depth).

uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D mask : filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 area = vec4(0.0, 0.0, 1024.0, 1024.0);
uniform vec2 cam_pos = vec2(0.0);
// Как у облаков (cloud_shadows): тот же шум, снос и размер
uniform vec2 drift = vec2(11.0, 4.0);
uniform float scale = 2400.0;
uniform float coverage = 0.5;
uniform float softness = 0.22;
// Насколько отражение «прилипает» к камере (0 — как земля, 1 — небо в бесконечности)
uniform float sky_follow = 0.8;
// Течение (мировые px/с) и блики
uniform vec2 flow = vec2(2.0, 22.0);
uniform vec4 moon_color : source_color = vec4(0.6, 0.7, 0.9, 1.0);
uniform float sheen = 0.6;
uniform float glint = 0.5;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 muv = (world_pos - area.xy) / area.zw;
	float m = texture(mask, muv).r;
	if (m < 0.003) {
		discard;
	}
	float t = TIME;
	// Отражение неба: точка неба, видная в воде, смещается вместе с камерой
	vec2 sky = world_pos - cam_pos * sky_follow;
	vec2 p = (sky - drift * t) / scale;
	float n = texture(noise, p).r * 0.65
		+ texture(noise, p * 2.7 + vec2(0.37, 0.71) - drift * t * 0.00012).r * 0.35;
	float clear_sky = 1.0 - smoothstep(coverage - softness, coverage + softness, n);
	// Рябь по течению искажает отражение
	vec2 fp = world_pos - flow * t;
	float r1 = texture(noise, fp / 70.0).r;
	float r2 = texture(noise, fp / 31.0 + vec2(0.5, 0.2)).r;
	float ripple = r1 * 0.6 + r2 * 0.4;
	vec3 bg = texture(screen_tex, SCREEN_UV).rgb;
	float s = sheen * clear_sky * (0.55 + 0.9 * ripple);
	// Блики: редкие яркие искры на гребнях ряби, только под чистым небом
	float g = smoothstep(0.66, 0.74, r2 * 0.55 + r1 * 0.45) * glint * (0.25 + 0.75 * clear_sky);
	vec3 add = bg * moon_color.rgb * s + moon_color.rgb * g * 0.12;
	COLOR = vec4(add * m, 0.0);
}
