shader_type canvas_item;

// Логотип главного меню: тлеющий жар в раскалённых (оранжевых) частях
// гравировки и редкая полоса света по металлу. Прозрачность лого больше не
// мигает — «дышит» только яркость жара.
//
// COLOR во fragment() уже равен текстуре * modulate — текстуру повторно не
// умножаем (см. ICON_FADE_CODE в hero_inventory_skin.gd).

// Положение полосы света: 0..1 по ширине лого, < 0 — полосы нет
uniform float sweep = -1.0;
// Размер узла лого: по нему локальные координаты переводятся в 0..1
uniform vec2 rect_size = vec2(760.0, 254.0);
// Общий подъём жара (вспышка при появлении)
uniform float heat = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	vec2 p = local_pos / rect_size;
	// «Раскалённость» пикселя: чем сильнее красный над синим, тем горячее
	float hot = smoothstep(0.18, 0.55, c.r - c.b);
	// Неровное дыхание жара: две медленные волны и бегущая по ширине
	float breath = 0.07 * sin(TIME * 1.1) + 0.05 * sin(TIME * 2.9 + p.x * 9.0)
		+ 0.04 * sin(TIME * 0.6 + p.x * 3.0 - p.y * 4.0);
	c.rgb *= 1.0 + hot * (heat + breath);
	// Полоса света: наклонная, узкая, тёплая
	if (sweep >= 0.0) {
		float x = p.x + (p.y - 0.5) * 0.25;
		float band = exp(-pow((x - sweep) / 0.045, 2.0));
		c.rgb += band * c.a * vec3(1.0, 0.86, 0.62) * (0.25 + 0.45 * hot);
	}
	COLOR = c;
}
