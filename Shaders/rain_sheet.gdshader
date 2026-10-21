shader_type canvas_item;
render_mode blend_add;
// rain_sheet.gdshader — пелена ливня (Levels/rain_system.gd). Прямоугольник
// во весь вид камеры, в мире; в нём — три слоя тонких косых струй разной
// дальности. Каждый слой — сетка: колонки вдоль наклона ветра, в колонке
// струи идут сериями со случайным сдвигом и скоростью, часть ячеек пустая
// (плотность). Дальние слои тоньше, тусклее, короче и сдвигаются за камерой
// медленнее (параллакс) — так дождь читается толщей, а не плёнкой на экране.
// Свет обычный (не unshaded): луна и костры подсвечивают струи — в пятнах
// света дождь блестит, в темноте почти тонет, как в жизни.

// Сколько ячеек заполнено струями (0..1) — меняется порывами
uniform float density : hint_range(0.0, 1.0) = 0.55;
// Наклон дождя: сдвиг по x на единицу падения по y (ветер)
uniform float slant = -0.22;
// Скорость падения ближнего слоя, пикселей мира в секунду
uniform float fall_speed = 760.0;
uniform vec4 rain_color : source_color = vec4(0.72, 0.8, 0.95, 1.0);
// Общая сила пелены
uniform float strength : hint_range(0.0, 3.0) = 1.0;
// Позиция камеры в мире — для параллакса слоёв
uniform vec2 cam_pos = vec2(0.0);
// Полуразмер вида камеры в мире и насколько пелена редеет у центра вида
// (там герой и бой): 0 — без расчистки, 1 — в центре дождя нет совсем.
// К краям экрана пелена возвращается в полную силу — дождь читается, но не
// лезет поверх боя
uniform vec2 view_half = vec2(320.0, 180.0);
uniform float clear_center : hint_range(0.0, 1.0) = 0.42;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Один слой струй. depth — 0 (ближний) .. 1 (дальний)
float layer(vec2 w, float depth, float t) {
	// Дальние слои "отстают" от камеры — параллакс глубины
	vec2 p = w - cam_pos * (depth * 0.6);
	float col_w = mix(5.0, 3.0, depth);          // ширина колонки
	float spacing = mix(150.0, 90.0, depth);     // шаг струй в колонке
	float len = mix(34.0, 16.0, depth);          // длина струи
	float speed = fall_speed * mix(1.0, 0.7, depth);
	// Ось вдоль падения с учётом наклона ветра
	float u = p.x - p.y * slant;
	float col = floor(u / col_w);
	float r1 = hash(vec2(col, depth * 17.0));
	float r2 = hash(vec2(col * 1.7, 3.1 + depth));
	float v = p.y - t * speed * (0.85 + 0.3 * r1) + r2 * 1000.0;
	float cell = floor(v / spacing);
	// Пустые ячейки — разреженность и неровность ливня
	float present = step(hash(vec2(col, cell)), density * mix(1.0, 0.8, depth));
	float f = fract(v / spacing) * spacing;      // 0..spacing вдоль струи
	// Голова струи ярче, хвост тает
	float along = smoothstep(len, 0.0, f) * smoothstep(0.0, 2.0, f);
	// Поперёк: тонкая линия ~1px, на дальних слоях бледнее
	float x = abs(fract(u / col_w) - 0.5 + (r2 - 0.5) * 0.6) * col_w;
	float across = smoothstep(0.9, 0.15, x);
	return present * along * across * mix(1.0, 0.45, depth);
}

void fragment() {
	float t = TIME;
	// Ближний слой — самый заметный, он тише остальных: глубину дают дальние
	float a = layer(world, 0.0, t) * 0.6 + layer(world, 0.5, t) * 0.75 + layer(world, 1.0, t) * 0.6;
	float d = length((world - cam_pos) / view_half);
	a *= mix(1.0 - clear_center, 1.0, smoothstep(0.15, 0.8, d));
	// COLOR на входе = modulate узла (текстура белая) — через него дом гасит
	// дождь под крышей (house_interior.gd, группа rain_fx)
	vec4 m = COLOR;
	COLOR = vec4(rain_color.rgb * a * strength * 0.5 * m.rgb * m.a, 1.0);
}
