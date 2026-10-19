shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// magic_scorch.gdshader — выжигание земли перед магом (ПКМ, mage_scorch.gd).
// Сетка — конус на земле: UV.x — поперёк конуса (0..1), UV.y — от мага вперёд
// (0 — у ног, 1 — дальний край). Фронт огня ползёт по UV.y = progress:
//   - впереди фронта — ничего, лишь слабое марево-предсвечение;
//   - на самом фронте — рваная раскалённая кромка (белое ядро -> голубой);
//   - за ним — мягкий отсвет огня на земле (сами языки пламени — отдельно,
//     в mage_scorch.gd, на шейдере столпов);
//   - дальше — обугленная земля.
// Один проход, премультиплицированная альфа: огонь — rgb без альфы (светится,
// как аддитив), уголь — альфа без rgb (затемняет землю, как обычный слой).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
// Где фронт огня (0..1 по длине конуса)
uniform float progress : hint_range(0.0, 1.2) = 0.0;
// Сила огня и угля — гаснут отдельно: огонь быстро, уголь долго
uniform float fire : hint_range(0.0, 1.0) = 1.0;
uniform float char_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 core_color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.42, 0.72, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.14, 0.32, 1.0, 1.0);
uniform vec4 char_color : source_color = vec4(0.02, 0.025, 0.045, 1.0);
uniform float seed = 0.0;

float noise(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// Рваные края конуса: бока изъедены шумом, а не ровные
	float side = 1.0 - abs(uv.x * 2.0 - 1.0);
	float n_side = noise(vec2(uv.y * 0.9 + seed, uv.x * 0.35 - t * 0.05));
	float side_mask = smoothstep(0.0, 0.28, side - (n_side - 0.5) * 0.35);
	// У самых ног узко и мягко — выжигание начинается из точки, а не обрезом
	float base_mask = smoothstep(0.0, 0.12, uv.y);
	// Дальний край — рваный, а не ровная дуга сетки
	float n_far = noise(vec2(uv.x * 1.3 - seed, 0.37 + seed));
	float far_mask = 1.0 - smoothstep(0.78 + n_far * 0.12, 0.97, uv.y);

	// Фронт неровный: языками вперёд и назад, и сам он чуть "кипит"
	float n_front = noise(vec2(uv.x * 0.8 + seed, t * 0.35));
	float n_front2 = noise(vec2(uv.x * 2.3 - seed, t * 0.9 + 3.0));
	float front = progress + (n_front - 0.5) * 0.14 + (n_front2 - 0.5) * 0.05;
	// d > 0 — за фронтом (уже горит/выжжено), d < 0 — впереди
	float d = front - uv.y;

	// Раскалённая кромка на самом фронте
	float rim = exp(-abs(d) * 30.0) * step(-0.05, d);
	// Дойдя до края, кромка не застывает дугой, а гаснет
	rim *= 1.0 - smoothstep(0.82, 1.02, progress);
	// Свечение земли под огнём: ярко у кромки, плавно гаснет к хвосту. Сам
	// огонь — языки пламени поверх (mage_scorch.gd), здесь только их отсвет;
	// медленный крупный шум — чтобы отсвет "дышал", а не лежал ровной заливкой
	float glow_n = noise(vec2(uv.x * 0.9 + seed, uv.y * 1.1 - t * 0.5));
	float burn = smoothstep(0.0, 0.03, d) * exp(-d * 3.2) * (0.6 + 0.4 * glow_n);
	// Марево впереди фронта — тонкое предсвечение, куда огонь вот-вот придёт
	float pre = exp(d * 22.0) * step(d, 0.0) * 0.35;

	float mask = side_mask * base_mask * far_mask;
	vec3 fire_rgb = core_color.rgb * rim * 0.9
		+ mid_color.rgb * (burn * 0.45 + rim * 0.5)
		+ edge_color.rgb * (burn * 0.3 + pre);
	fire_rgb *= mask * fire;

	// Обугленная земля: за фронтом, плотнее в середине, с пятнистой фактурой
	float char_n = noise(vec2(uv.x * 1.7 + seed, uv.y * 2.1 - seed));
	float charred = smoothstep(0.0, 0.08, d) * (0.55 + 0.45 * char_n) * mask * char_amount;
	// Уголь затемняет землю (альфа), под огнём он не должен гасить свечение
	float a = charred * 0.78;
	COLOR = vec4(fire_rgb + char_color.rgb * a, a);
}
