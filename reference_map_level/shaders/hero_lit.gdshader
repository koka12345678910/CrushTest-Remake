shader_type canvas_item;
// Герой под настоящим светом карты (reference_map, scripts/hero_light.gd
// ставит этот шейдер копии материала героя; кладбище и враги — без него).
//
// Цвет, палитра и проработка — как в Shaders/sprite_detail.gdshader (тот же
// include). Сверху:
//   - нарисованная художником тень под ногами вырезана (её даёт свет);
//   - нормаль фигуры строится из силуэта и складок (hero_normal);
//   - фигура "стоит лицом к камере": плоское повёрнуто на юг (к зрителю).
//     Огонь перед героем освещает его целиком; огонь за спиной — фигура
//     в тени, светится только контур со стороны огня (контровой свет);
//   - свет, который загорожен стеной или домом (hero_light.gd проверяет
//     лучом), почти не светит на героя — он стоит в тени.

#define HERO_LIT
#include "res://Shaders/sprite_detail.gdshaderinc"

// Насколько плоское смотрит к зрителю (на юг)
uniform float front_tilt = 0.6;
// Мягкость перехода свет/тень (обёртка) и подсветка теневой стороны
uniform float wrap = 0.4;
uniform float fill = 0.22;
uniform float key_gain = 1.6;
// Потолок света от одного источника (иначе у самого огня фигура белеет)
uniform float max_k = 2.0;
// Луна мягче огня: высокая и рассеянная
uniform float moon_gain = 0.8;
// Контровой свет: край фигуры со стороны огня за спиной
uniform float rim_gain = 3.2;
// Высота огня над героем, экранные px: меньше — свет скользит сильнее
uniform float light_height = 80.0;
// Загороженные источники (экранные позиции) и сколько света от них остаётся
uniform vec4 blocked[4];
uniform int blocked_n = 0;
uniform float blocked_keep = 0.12;
// Луна (Levels/moonlight.gd moon_marker: альфа цвета 0.5) — одно направление
const vec3 MOON_DIR = vec3(-0.5, -0.62, 0.6);

void light() {
	// Свечение вокруг героя (PlayerGlow, помечено альфой 0.75) — ровная
	// подсветка, чтобы его было видно в темноте, а не источник со стороны
	if (LIGHT_IS_DIRECTIONAL || abs(LIGHT_COLOR.a - 0.75) < 0.002) {
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
	} else {
		vec3 n = normalize(NORMAL + vec3(0.0, front_tilt, 0.0));
		vec3 l;
		float block = 1.0;
		float gain = key_gain;
		if (abs(LIGHT_COLOR.a - 0.5) < 0.002) {
			l = normalize(MOON_DIR);
			gain = key_gain * moon_gain;
		} else {
			l = normalize(vec3(LIGHT_POSITION.xy - LIGHT_VERTEX.xy, light_height));
			for (int i = 0; i < 4; i++) {
				if (i < blocked_n && distance(blocked[i].xy, LIGHT_POSITION.xy) < 3.0) {
					block = blocked_keep;
				}
			}
		}
		float d = dot(n, l);
		float diff = clamp((d + wrap) / (1.0 + wrap), 0.0, 1.0);
		// Край силуэта, повёрнутый к огню, — контровой свет (сильнее, когда
		// огонь сзади: lxy вверх по экрану, а плоское смотрит вниз)
		float edge = smoothstep(0.06, 0.32, 1.0 - NORMAL.z);
		vec2 nx = NORMAL.xy / max(length(NORMAL.xy), 1e-4);
		vec2 lx = l.xy / max(length(l.xy), 1e-4);
		float back = clamp(-l.y * 1.5 + 0.3, 0.0, 1.0);
		float rim = edge * clamp(dot(nx, lx), 0.0, 1.0) * rim_gain * (0.3 + 0.7 * back);
		float k = min(fill + diff * gain + rim, max_k) * block;
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * k, LIGHT_COLOR.a);
	}
}
