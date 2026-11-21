shader_type canvas_item;
render_mode unshaded;
// Марево над огнём (reference_map, scripts/fire_fx.gd): горячий воздух
// дрожит и течёт вверх — картинка за ним чуть плывёт. Сильнее всего прямо
// над языками, к краям и вверх сходит на нет. Все кадры марева лежат в одном
// узле над Objects, у каждого — своя копия экрана под ним (BackBufferCopy).
// Цвет вершин: r — сид, a — сила (0.5 — норма).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 2.2;   // сдвиг, экранные px
uniform float scale = 9.0;
uniform float speed = 2.4;

varying vec4 v_data;

void vertex() {
	v_data = COLOR;
}

vec2 h2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float gn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(h2(i), f), dot(h2(i + vec2(1, 0)), f - vec2(1, 0)), u.x),
			mix(dot(h2(i + vec2(0, 1)), f - vec2(0, 1)), dot(h2(i + vec2(1, 1)), f - vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float seed = v_data.r * 31.0;
	float k = v_data.a * 2.0;
	vec2 uv = UV;
	float h = 1.0 - uv.y;
	vec2 p = vec2(uv.x * scale * 0.6, uv.y * scale) + vec2(seed, TIME * speed);
	vec2 off = vec2(gn(p), gn(p + vec2(17.3, 3.1))) ;
	off += 0.5 * vec2(gn(p * 2.1 + 4.0), gn(p * 2.1 + 9.0));
	float x = uv.x * 2.0 - 1.0;
	float m = (1.0 - x * x) * smoothstep(0.0, 0.25, h) * (1.0 - smoothstep(0.45, 1.0, h));
	m *= m;
	vec2 d = off * strength * m * k * SCREEN_PIXEL_SIZE;
	d.y *= 0.6;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + d).rgb, 1.0);
}
