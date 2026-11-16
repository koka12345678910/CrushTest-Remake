shader_type canvas_item;
// Ветер для объектов карты + окно прозрачности вокруг героя (как
// Shaders/occlusion_fade_plain.gdshader: цвет как нарисован, без квадрата).
// Раздаёт reference_map_level/scripts/immersion.gd: кронам, кустам, траве,
// камышу (наклон), шатрам и знамёнам (рябь ткани), петле виселицы (маятник).
//
// Положение внутри спрайта/тайла берётся из VERTEX_ID: прямоугольник рисуется
// четырьмя вершинами 0 (лево-верх), 1 (лево-низ), 2 (право-низ), 3 (право-верх).
// UV для этого не годится — у тайлов и спрайтов с region это координаты атласа.

#include "res://Shaders/occlusion_fade.gdshaderinc"
// Свет огня по карте нормалей (без карты — как обычно)
#include "res://reference_map_level/shaders/normal_light.gdshaderinc"

// ---- Наклон (кроны, трава): верх смещается, основание стоит ----
// Мировые px на верхнем краю при порыве 1
uniform float sway_amp = 0.0;
uniform float sway_speed = 0.8;
// Мелкое дрожание листвы, тексели (0 — нет)
uniform float shimmer_amp = 0.0;

// ---- Ткань ----
// Рябь, тексели. Режим 1 — висит сверху (знамя: низ гуляет сильнее),
// 2 — натянута (шатёр: сильнее в середине полотна)
uniform float flutter_amp = 0.0;
uniform int flutter_mode = 1;
uniform float flutter_speed = 3.0;

// ---- Маятник (петля виселицы): область в долях спрайта и размах в текселях ----
uniform vec4 rope_rect = vec4(0.0);
uniform float rope_amp = 0.0;
uniform float rope_period = 3.4;

// ---- Герой раздвигает траву и кусты: верх отклоняется от него ----
// Сила (мировые px), радиус и высота растения (от верха картинки до корня)
uniform float push_amp = 0.0;
uniform float push_radius = 26.0;
uniform float plant_h = 30.0;

// Общая сила ветра (immersion.gd выставляет всем материалам ветра)
uniform float wind_strength = 1.0;

varying vec2 quad_uv;
varying vec4 vert_color;

float gust(vec2 wp, float t) {
	// Порыв бежит по карте волной: соседние деревья качаются почти вместе,
	// дальние — со сдвигом
	float g = 0.6 + 0.4 * sin(t * 0.21 - wp.x * 0.0012 + wp.y * 0.0005)
		* sin(t * 0.33 + wp.y * 0.0008 + 1.3);
	return g * max(wind_strength, 0.0);
}

void vertex() {
	quad_uv = vec2(float(VERTEX_ID == 2 || VERTEX_ID == 3), float(VERTEX_ID == 1 || VERTEX_ID == 2));
	vert_color = COLOR;
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (sway_amp > 0.0) {
		float ph = TIME * sway_speed + wp.x * 0.0035 + wp.y * 0.0021;
		float s = sin(ph) * 0.75 + sin(ph * 2.37 + 1.7) * 0.25;
		// Наклон всегда немного по ветру плюс качание
		s = 0.35 + s * 0.65;
		float h = 1.0 - quad_uv.y;
		float sx = max(length(MODEL_MATRIX[0].xy), 0.0001);
		VERTEX.x += s * gust(wp, TIME) * sway_amp * h / sx;
	}
	if (push_amp > 0.0) {
		float h = 1.0 - quad_uv.y;
		float sx = max(length(MODEL_MATRIX[0].xy), 0.0001);
		vec2 root = vec2(wp.x, wp.y + plant_h * h);
		vec2 d = root - occlusion_player_pos;
		float k = 1.0 - smoothstep(push_radius * 0.35, push_radius, length(d * vec2(1.0, 1.6)));
		VERTEX.x += sign(d.x + 0.001) * k * push_amp * h / sx;
		VERTEX.y += k * push_amp * 0.35 * h / sx;
	}
	occlusion_world_pos = occlusion_world(VERTEX, MODEL_MATRIX);
	occlusion_origin = occlusion_world(vec2(0.0), MODEL_MATRIX);
}

void fragment() {
	vec2 wp = occlusion_world_pos;
	vec2 off = vec2(0.0);
	float t = TIME;
	if (shimmer_amp > 0.0) {
		float h = 1.0 - quad_uv.y;
		float g = gust(wp, t);
		off += vec2(sin(wp.x * 0.21 + t * 2.9) * sin(wp.y * 0.17 - t * 2.1),
			sin(wp.x * 0.13 - t * 2.5 + wp.y * 0.11) * 0.6) * shimmer_amp * h * g;
	}
	if (flutter_amp > 0.0) {
		float w = flutter_mode == 1 ? quad_uv.y : sin(3.14159 * quad_uv.y) * sin(3.14159 * quad_uv.x);
		float g = gust(wp, t);
		float wave = sin(wp.x * 0.09 + wp.y * 0.05 - t * flutter_speed)
			+ 0.5 * sin(wp.y * 0.13 - t * flutter_speed * 1.7 + 2.0);
		off += vec2(wave, 0.35 * cos(wp.x * 0.07 - t * flutter_speed * 1.3)) * flutter_amp * w * g;
	}
	if (rope_amp > 0.0) {
		vec2 q = quad_uv;
		if (q.x > rope_rect.x && q.x < rope_rect.z && q.y > rope_rect.y) {
			float k = clamp((q.y - rope_rect.y) / max(rope_rect.w - rope_rect.y, 0.001), 0.0, 1.0);
			float swing = sin(t * 6.2832 / rope_period) * (0.6 + 0.4 * gust(wp, t));
			off.x -= swing * rope_amp * k;
		}
	}
	if (off != vec2(0.0)) {
		COLOR = texture(TEXTURE, UV + off * TEXTURE_PIXEL_SIZE) * vert_color;
	}
	COLOR.rgb *= object_brightness;
	COLOR.a *= occlusion_alpha_depth(occlusion_world_pos, occlusion_origin);
}
