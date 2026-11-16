// Свет огня по карте нормалей (reference_map, scripts/normal_maps.gd).
//
// Обычный свет Godot с картой нормалей считает N·L от высоты источника: у
// факелов высота 0, и всё плоское стало бы чёрным, а с высотой — заметно
// темнее земли без нормалей. Здесь рельеф только ПЕРЕРАСПРЕДЕЛЯЕТ свет:
// плоский участок освещён ровно как раньше (k = 1), склон к огню — ярче,
// от огня — темнее. Без карты нормалей NORMAL = (0,0,1) — свет как обычно.
// Тени (SHADOW_MODULATE) Godot накладывает после.

// Насколько рельеф меняет свет (0 — как без нормалей)
uniform float relief_strength = 1.0;
// Высота огня над рисунком, экранные px: меньше — свет скользит и рельеф резче
uniform float relief_height = 90.0;

void light() {
	vec3 l = normalize(vec3(LIGHT_POSITION.xy - LIGHT_VERTEX.xy, relief_height));
	float k = 1.0 + relief_strength * (dot(NORMAL, l) - l.z);
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * clamp(k, 0.2, 2.2), LIGHT_COLOR.a);
}
