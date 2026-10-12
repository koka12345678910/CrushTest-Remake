// occlusion_fade.gdshaderinc — "окно" прозрачности вокруг игрока.
//
// Всё, что рисуется поверх персонажа (пропсы, растения, магазин), в овале
// вокруг него становится полупрозрачным — видно, где он стоит, но сам
// предмет не пропадает целиком. Позицию игрока каждый кадр пишет
// Levels/player_spawner.gd в глобальный параметр occlusion_player_pos
// (объявлен в project.godot, раздел [shader_globals]).
//
// Подключение: #include этого файла, в vertex() —
// occlusion_world_pos = occlusion_world(VERTEX,
// MODEL_MATRIX), в fragment() — COLOR.a *= occlusion_alpha(occlusion_world_pos).
// Varying Godot разрешает трогать только прямо в vertex()/fragment(), поэтому
// функции получают и отдают координату через аргументы

global uniform vec2 occlusion_player_pos;

// Сколько остаётся видно в центре окна (0 — дыра насквозь, 1 — без эффекта)
uniform float occlusion_min_alpha : hint_range(0.0, 1.0) = 0.35;
// Радиус окна по горизонтали (px); по вертикали — умножается на stretch
uniform float occlusion_radius : hint_range(4.0, 200.0) = 30.0;
uniform float occlusion_stretch_y : hint_range(0.5, 3.0) = 1.35;
// Ширина мягкого края (px)
uniform float occlusion_softness : hint_range(0.0, 100.0) = 14.0;
// Сдвиг центра окна от позиции игрока (px) — центр спрайта вместо ног и т.п.
uniform vec2 occlusion_offset = vec2(0.0, -4.0);

// Осветление предметов (не про окно, но нужно тем же слоям): ночной свет
// синеватый, а зелень/дерево/камень пропсов синий почти не отражают и уходят
// в черноту на фоне светлой земли. 1.0 — как нарисовано
uniform float object_brightness : hint_range(0.5, 3.0) = 1.0;

varying vec2 occlusion_world_pos;

vec2 occlusion_world(vec2 vertex, mat4 model) {
	return (model * vec4(vertex, 0.0, 1.0)).xy;
}

float occlusion_alpha(vec2 world_pos) {
	vec2 d = world_pos - (occlusion_player_pos + occlusion_offset);
	d.y /= occlusion_stretch_y;
	float t = smoothstep(occlusion_radius, occlusion_radius + occlusion_softness, length(d));
	return mix(occlusion_min_alpha, 1.0, t);
}

// ---- Только когда предмет действительно перед игроком ----
// Окно имеет смысл, лишь если предмет рисуется ПОВЕРХ персонажа, то есть его
// основание (линия сортировки по глубине) ниже ног игрока. Стоит герой перед
// предметом — его видно целиком, и предмет остаётся непрозрачным.
// Режим: 0 — окно всегда (как раньше, level_01), 1 — основание = позиция узла
// (спрайты: дома, ограды, пропсы) + occlusion_sort_offset, 2 — основание
// клетки берётся из карты occlusion_base_map (тайловые слои: деревья, могилы):
// R = (y_sort_origin тайла + 32) / 255, по текселю на клетку
uniform int occlusion_depth_mode = 0;
uniform float occlusion_sort_offset = 0.0;
uniform sampler2D occlusion_base_map : filter_nearest;
uniform float occlusion_cell = 16.0;

varying vec2 occlusion_origin;

float occlusion_alpha_depth(vec2 world_pos, vec2 origin) {
	float a = occlusion_alpha(world_pos);
	if (occlusion_depth_mode == 0) {
		return a;
	}
	float sort_y = origin.y + occlusion_sort_offset;
	if (occlusion_depth_mode == 2) {
		ivec2 size = textureSize(occlusion_base_map, 0);
		ivec2 cell = clamp(ivec2(floor(world_pos / occlusion_cell)), ivec2(0), size - 1);
		float off = texelFetch(occlusion_base_map, cell, 0).r * 255.0 - 32.0;
		sort_y = (float(cell.y) + 0.5) * occlusion_cell + off;
	}
	// Перед игроком — окно работает, за ним — предмет как есть
	float in_front = smoothstep(occlusion_player_pos.y - 1.0, occlusion_player_pos.y + 3.0, sort_y);
	return mix(1.0, a, in_front);
}
