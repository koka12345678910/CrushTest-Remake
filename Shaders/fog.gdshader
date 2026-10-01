shader_type canvas_item;
render_mode unshaded;
// Туман уровня: рваные клочья по всей карте + плотная стена тумана по краям
// (там, где лес уходит за границу карты), а вокруг игрока он редеет, чтобы
// не мешать бою. Рисуется в мировых координатах — при движении камеры клочья
// остаются на месте и плывут по ветру, а не прилипают к экрану.
// Позицию игрока даёт тот же глобальный параметр, что и окну прозрачности
// (occlusion_player_pos, пишет Levels/player_spawner.gd).

global uniform vec2 occlusion_player_pos;

uniform vec4 fog_color : source_color = vec4(0.46, 0.5, 0.52, 1.0);
// Плотность клочьев внутри карты
uniform float base_density : hint_range(0.0, 1.0) = 0.32;
// Плотность у границ карты
uniform float edge_density : hint_range(0.0, 1.0) = 0.92;
// Игровая область (x0, y0, x1, y1) — за её пределами туман густой
uniform vec4 play_rect = vec4(0.0, 0.0, 3072.0, 1536.0);
// На каком расстоянии от границы туман набирает полную плотность
uniform float edge_width = 420.0;
uniform float noise_scale = 0.0022;
uniform vec2 wind = vec2(14.0, 5.0);
// "Окно" вокруг игрока
uniform float player_clear_radius = 170.0;
uniform float player_clear_strength : hint_range(0.0, 1.0) = 0.65;

varying vec2 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos * noise_scale;
	vec2 drift = TIME * wind * noise_scale;
	float n1 = fbm(p + drift);
	float n2 = fbm(p * 2.2 - drift * 0.6 + vec2(31.7, 5.3));
	float clouds = n1 * 0.65 + n2 * 0.35;
	float wisps = smoothstep(0.38, 0.78, clouds);

	// Расстояние до ближайшей границы игровой области (внутри — положительное)
	vec2 dmin = world_pos - play_rect.xy;
	vec2 dmax = play_rect.zw - world_pos;
	float d = min(min(dmin.x, dmin.y), min(dmax.x, dmax.y));
	float edge = 1.0 - smoothstep(-edge_width * 0.3, edge_width, d);

	float density = base_density * wisps + edge * edge_density * (0.65 + 0.35 * clouds);

	float pd = length(world_pos - occlusion_player_pos);
	density *= mix(1.0 - player_clear_strength, 1.0, smoothstep(player_clear_radius * 0.35, player_clear_radius, pd));

	COLOR = vec4(fog_color.rgb, clamp(density, 0.0, 1.0) * fog_color.a);
}
