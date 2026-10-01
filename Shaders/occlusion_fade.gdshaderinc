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
