shader_type canvas_item;
// Земля лагеря: вытоптанная грязь и выжженные места поверх травы карты.
// TEXTURE — маска лагеря (tools/camp_hd.gd): R — где грязь (мягкий рваный
// край), G — где пепел, B — крупные пятна для второй выборки грязи (чтобы
// повтор плитки не читался). Плитки грязи и пепла — бесшовные, в мировых px.

uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D ash_tex : source_color, repeat_enable, filter_linear_mipmap;
// Сколько px мира занимает одна плитка
uniform float tile_px = 360.0;
// Размер всей маски в px мира (размер текстуры * масштаб спрайта)
uniform vec2 area_px = vec2(2816.0, 1728.0);

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	vec2 p = UV * area_px / tile_px;
	vec3 mud = texture(mud_tex, p).rgb;
	// Вторая выборка — другой масштаб и сдвиг, смешивается крупными пятнами
	vec3 mud2 = texture(mud_tex, p * 0.71 + vec2(0.37, 0.61)).rgb;
	mud = mix(mud, mud2, m.b);
	vec3 ash = texture(ash_tex, p * 0.87 + vec2(0.13, 0.47)).rgb;
	vec3 c = mix(mud, ash, m.g);
	// COLOR тут уже умножен на маску (в Godot 4 в нём текстура) — не берём
	COLOR = vec4(c, m.r);
}
