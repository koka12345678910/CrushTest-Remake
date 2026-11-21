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

// Луна (Levels/moonlight.gd с moon_marker): огромные плитки света, центр
// плитки — не "где луна". Помечена альфой цвета 0.5 (яркость удвоена,
// Godot умножает свет на альфу — итог тот же) и светит отовсюду с одной
// стороны — сверху-слева, высоко, рельеф мягче огненного
const vec3 MOON_DIR = vec3(-0.5, -0.62, 0.6);

void light() {
	vec3 l = normalize(vec3(LIGHT_POSITION.xy - LIGHT_VERTEX.xy, relief_height));
	float rs = relief_strength;
	if (abs(LIGHT_COLOR.a - 0.5) < 0.002) {
		l = normalize(MOON_DIR);
		rs *= 0.55;
	}
	float k = 1.0 + rs * (dot(NORMAL, l) - l.z);
	// Направленный свет — рассеянный свет неба и вспышки молний (погода):
	// у него нет точки, откуда светить, рельеф от него не нужен
	if (LIGHT_IS_DIRECTIONAL) {
		k = 1.0;
	}
	vec3 albedo = COLOR.rgb;
#ifdef HERO_SIL
	// Силуэт героя светится сам: свет падает только на предмет под ним
	albedo = max(albedo - hero_sil_add, vec3(0.0));
#endif
	LIGHT = vec4(LIGHT_COLOR.rgb * albedo * LIGHT_ENERGY * clamp(k, 0.2, 2.2), LIGHT_COLOR.a);
}
