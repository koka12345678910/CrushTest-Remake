// Силуэт героя сквозь препятствия (reference_map, scripts/hero_silhouette.gd).
//
// Вместо прозрачного "окна" дома, стены и кроны остаются непрозрачными, а
// там, где они закрывают героя, на них проступает его силуэт: светлый контур
// по краю фигуры и лёгкая заливка внутри. Форму героя даёт маска — его кадр,
// который каждый кадр рисует отдельный невидимый вьюпорт (только героя),
// в мировых координатах hero_mask_rect. Перед героем ли предмет — та же
// проверка глубины, что у окна прозрачности (occlusion_fade.gdshaderinc,
// подключать раньше этого файла).
//
// Цвет контура — экранный: шейдер затенённый, ночной CanvasModulate его
// умножит, поэтому цвет заранее делится на него (hero_sil_comp), а свет
// огня и луны в пикселях силуэта гасится в light() (normal_light, HERO_SIL).
// Всё это задаёт скрипт; без него (hero_sil_on = 0) шейдер как прежде.

uniform sampler2D hero_mask : filter_linear, repeat_disable;
// Мировой прямоугольник маски: xy — левый верх, zw — размер
uniform vec4 hero_mask_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 hero_sil_color : source_color = vec4(0.62, 0.74, 1.0, 1.0);
uniform vec3 hero_sil_comp = vec3(1.0);
uniform float hero_sil_on = 0.0;
// Толщина контура, мировые px; сила контура и заливки
uniform float hero_sil_rim_px = 1.0;
uniform float hero_sil_rim = 0.8;
uniform float hero_sil_fill = 0.1;

// Добавка силуэта к цвету: light() освещает только сам предмет под ней
varying vec3 hero_sil_add;

// Стоит ли предмет перед героем (1) или за ним (0) — как в окне прозрачности
float hero_sil_front(vec2 world_pos, vec2 origin) {
	if (occlusion_depth_mode == 0) {
		return 1.0;
	}
	float sort_y = origin.y + occlusion_sort_offset;
	if (occlusion_depth_mode == 2) {
		ivec2 size = textureSize(occlusion_base_map, 0);
		ivec2 cell = clamp(ivec2(floor(world_pos / occlusion_cell)), ivec2(0), size - 1);
		float off = texelFetch(occlusion_base_map, cell, 0).r * 255.0 - 32.0;
		sort_y = (float(cell.y) + 0.5) * occlusion_cell + off;
	}
	return smoothstep(occlusion_player_pos.y - 1.0, occlusion_player_pos.y + 3.0, sort_y);
}

// add — добавка силуэта к цвету: шейдер кладёт её в hero_sil_add (для light())
vec4 hero_silhouette(vec4 col, vec2 world_pos, vec2 origin, out vec3 add) {
	add = vec3(0.0);
	float s;
	s = 0.0;
	if (hero_sil_on <= 0.0 || col.a < 0.02) {
		return col;
	}
	vec2 uv = (world_pos - hero_mask_rect.xy) / hero_mask_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return col;
	}
	float front = hero_sil_front(world_pos, origin);
	if (front <= 0.0) {
		return col;
	}
	float a = texture(hero_mask, uv).a;
	vec2 px = hero_sil_rim_px / hero_mask_rect.zw;
	float n0 = texture(hero_mask, uv + vec2(px.x, 0.0)).a;
	float n1 = texture(hero_mask, uv - vec2(px.x, 0.0)).a;
	float n2 = texture(hero_mask, uv + vec2(0.0, px.y)).a;
	float n3 = texture(hero_mask, uv - vec2(0.0, px.y)).a;
	float n4 = texture(hero_mask, uv + px * 0.7).a;
	float n5 = texture(hero_mask, uv - px * 0.7).a;
	float n6 = texture(hero_mask, uv + vec2(px.x, -px.y) * 0.7).a;
	float n7 = texture(hero_mask, uv + vec2(-px.x, px.y) * 0.7).a;
	float mx = max(max(max(n0, n1), max(n2, n3)), max(max(n4, n5), max(n6, n7)));
	float mn = min(min(min(n0, n1), min(n2, n3)), min(min(n4, n5), min(n6, n7)));
	// Контур — по обе стороны края фигуры; заливка — внутри, слабо
	float rim = clamp((max(mx, a) - min(mn, a)) * 1.3, 0.0, 1.0);
	s = max(rim * hero_sil_rim, a * hero_sil_fill) * front * hero_sil_on;
	if (s <= 0.001) {
		return col;
	}
	add = hero_sil_color.rgb * hero_sil_comp * s;
	col.rgb = col.rgb * (1.0 - s) + add;
	return col;
}
