shader_type canvas_item;
render_mode blend_add, unshaded;
// Блик удара (VFX/VFX_scene/knight_fx.gd): яркое ядро и лучи-звезда — длинный
// горизонтальный, короче вертикальный и слабые диагонали. С cut = 1 остаётся
// только тонкая черта — "разрез" при попадании клинка.

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float intensity = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// 0 — звезда, 1 — одна черта-разрез
uniform float cut : hint_range(0.0, 1.0) = 0.0;
uniform float ray_len = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 40.0) * (1.0 - cut * 0.6);
	float h = exp(-p.y * p.y * 900.0) * pow(max(1.0 - abs(p.x) / ray_len, 0.0), 2.0);
	float v = exp(-p.x * p.x * 900.0) * pow(max(1.0 - abs(p.y) / (ray_len * 0.55), 0.0), 2.0) * (1.0 - cut);
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	float dg = (exp(-q.y * q.y * 1400.0) + exp(-q.x * q.x * 1400.0))
		* pow(max(1.0 - r / (ray_len * 0.45), 0.0), 2.0) * 0.45 * (1.0 - cut);
	float halo = exp(-r * r * 6.0) * 0.25 * (1.0 - cut);
	float a = (core + h + v + dg + halo) * fade * intensity;
	vec3 col = mix(color.rgb, vec3(1.0), clamp(core + h * 0.5, 0.0, 1.0));
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
