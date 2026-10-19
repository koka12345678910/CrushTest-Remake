shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// magic_fire_cloud.gdshader — один клуб огненного облака выжигания мага
// (mage_scorch.gd). Квадрат с клубом: форма — круг, изъеденный шумом по краю
// ("цветная капуста" клубящегося огня); внутри — горячее ядро, голубое тело,
// яркие струи; к старости огонь остывает и клуб становится тёмным дымом.
// Шум с завихрением (domain warp) и сносом вверх — клуб "перекатывается",
// а не просто светится пятном.
// Премультиплицированная альфа: огонь — rgb без альфы (светится), дым —
// альфа (затемняет то, что под ним) — один проход на клуб.
//   age — 0: только вспыхнул, 1: догорел; fade — общая прозрачность

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
uniform vec4 core_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.38, 0.72, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.1, 0.24, 1.0, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.05, 0.07, 0.14, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME;
	vec2 q = UV * 0.5 + vec2(seed, seed * 0.73);

	// Завихрение: координаты шума сами гуляют по шуму — клубы закручиваются
	vec2 warp = vec2(
		texture(noise_tex, q + vec2(t * 0.06, -t * 0.1)).r,
		texture(noise_tex, q * 1.3 + vec2(-t * 0.08, -t * 0.12) + 4.1).r) - 0.5;
	// Крупные клубы и мелкие завитки, оба сносит вверх — огонь поднимается
	float n1 = texture(noise_tex, q + warp * 0.4 + vec2(0.0, t * 0.16)).r;
	float n2 = texture(noise_tex, q * 2.6 + warp * 0.6 + vec2(0.31, t * 0.38)).r;
	float n = n1 * 0.62 + n2 * 0.38;

	// Форма клуба: круг (чуть приплюснут снизу — лежит на огне под ним),
	// край изъеден шумом. С возрастом клуб рыхлеет и рассеивается
	float r = length(p * vec2(1.0, mix(1.15, 1.0, step(0.0, -p.y))));
	float edge = 0.95 - age * 0.12;
	float soft = 0.42 + age * 0.25;
	float dens = smoothstep(edge, edge - soft, r + (n - 0.5) * 0.8);

	// Жар: горячее всего в нижней середине клуба, шум рвёт его на языки;
	// остывает с возрастом
	float core_shape = 1.0 - (r + (n2 - 0.5) * 0.7 - p.y * 0.3);
	float heat = clamp(dens * smoothstep(0.0, 0.9, core_shape) * 1.5 * (1.0 - age * age * 0.95) - age * 0.15, 0.0, 1.0);

	vec3 fire = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.08, 0.5, heat));
	fire = mix(fire, core_color.rgb, smoothstep(0.78, 1.0, heat));
	// Яркие струи-прожилки внутри горячего
	float fil = smoothstep(0.6, 0.78, n2) * smoothstep(0.2, 0.6, heat);
	// Огонь виден там, где есть жар; холодные края клуба — синяя дымка
	float glow = dens * (smoothstep(0.02, 0.35, heat) + 0.18 * (1.0 - age));
	vec3 rgb = fire * glow * (0.85 + fil * 0.9) * intensity;

	// Дым: остывший клуб темнеет и затеняет то, что под ним
	float smoke = dens * smoothstep(0.3, 0.95, age) * (0.45 + 0.35 * n1) * (1.0 - heat);

	COLOR = vec4((rgb + smoke_color.rgb * smoke) * fade, smoke * 0.75 * fade);
}
