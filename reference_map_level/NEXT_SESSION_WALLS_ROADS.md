# Хольмвик — следующая сессия: чёткие стены, без зазоров, каменные улицы

Состояние на 2026-11-19 (ничего из этого ещё не закоммичено в момент записи):
арт партии 3 встал на карту через `tools/holmvik_art3.gd` (шаги `atlas`,
`walls`, `houses`, `siege`), атлас `textures/town_art3_hd.png`, нормали
`textures/normals/town_art3_hd_n.png`. Отзыв: стены хорошие, но мыльные;
между кусками стены зазоры; башня у старта (внешние ворота) мыльная; улицы
города — земля и трава, нужен камень.

---

## 1. Что не так и почему (замеры)

### 1.1 Мыло

Камера в игре x2.2 (зоны дают ещё 0.86..1.09). Чтобы картинка была чёткой,
на один пиксель экрана должен приходиться хотя бы один тексель:
**экран/тексель ≤ 1.0**. Сейчас:

| предмет | тексель/px мира | экран/тексель | вердикт |
|---|---|---|---|
| gatehouse (ворота, обе) | 1.31 | **1.69** | сильное мыло |
| tower_round (сев. стена) | 1.39 | **1.58** | сильное мыло |
| tower_square (угловые башни, у старта тоже) | 1.60 | **1.38** | мыло |
| wall_front / wall_breach | 2.05 | 1.07 | на грани |
| wall_side | 2.00 | 1.10 | на грани |
| дома v3 | 2.0–2.35 | 0.94–1.10 | терпимо |
| осада | 2.2–3.3 | 0.66–0.99 | чётко |

Причины:
- **Мало пикселей в исходнике.** Все 7 предметов стены GPT нарисовал на одном
  листе 1448×1086. Ворота там ~630 px в ширину, круглая башня ~300 px,
  квадратная ~260 px. В игре ворота растянуты до 360 px мира, это почти
  800 px экрана. Отсюда растяжение в 1.7 раза.
- Я ещё и **увеличил** башни и ворота (`TOWER_SQUARE_K 1.25`, `GATE_W_WORLD 360`,
  `TOWER_ROUND_W 165`), чтобы они были не меньше старых деревянных.
- Сам рисунок на общем листе мягкий: GPT экономит детали, когда предметов много.
- Атлас печётся при `TEX_SCALE 2.0`, а камера даёт до 2.4. Даже «родной»
  масштаб чуть растягивается.
- Нет повышения резкости после уменьшения (в `holmvik_art3.gd` нет `AU.unsharp`).
- Сжатие BPTC без мипмапов — для стен лучше проверить Lossless.

### 1.2 Зазоры между кусками стены

Секции стоят встык (шаг = ширина, 177 px). Но края у картинки рваные:

```
wall_front, 364 px: непрозрачно по столбцам — x0: 0%, x5: 10%, x10: 42%, x20: 92% … x353: 44%, x358: 7%, x363: 0%
wall_breach, 423 px: x10: 21%, x20: 72% … x412: 47%, x417: 4%
```

У каждого края ~15–20 текселей полупустые (осыпавшиеся углы и камни у
подножия). На стыке выходит щель ~15 px мира. GPT не сделал секцию бесшовной,
хотя об этом просили. Та же история у `wall_side` по вертикали (сверху и снизу
~10 текселей пустоты).

### 1.3 Улицы — земля и трава

Улицы Хольмвика рисует `holmvik_town.gd → _paint_streets()` в **маске троп**
(`terrain/paths.res`, канал R), то есть утоптанной землёй. Брусчатка
(`terrain/cobble_map.res`, шейдер `cobble_*`) осталась только там, где была
старая мостовая (главная улица до реки, площадь, южная улочка, причал), и
частично стёрта, когда ставили дома.

**Ловушка:** после `widen_map.gd` мир стал шире: в материале
`cobble_rect / path_rect / wear_rect = (-3520, -704, 9408, 5120)`. Но в
`tools/cobble_road.gd`, `forest_paths.gd`, `build_terrain.gd` и
`collision_audit.gd` всё ещё `WORLD := Rect2i(-3520, -704, 8640, 5120)`.
Если запустить `cobble_road.gd -- mask` как есть, маска съедет. **Сначала
поправить WORLD на 9408** в этих скриптах (или брать из материала).

---

## 2. План работ (по порядку)

### Шаг A. Принять новый арт (раздел 3)
Положить картинки в `textures/src/hd/props_v4/` и `textures/src/hd/roads_v2/`.
Имена — из заголовков промптов. По одному предмету на картинку.

### Шаг B. Стены без мыла — `holmvik_art3.gd`
1. Новый лист в `SHEETS`: каждая картинка из `props_v4/` — один предмет со
   своим масштабом по ширине в мире (не общий масштаб листа).
2. Печь стены, башни и ворота с `TEX_SCALE 2.5` (отдельный атлас
   `town_walls_hd.png`, чтобы дома и осада не выросли в памяти). Спрайты —
   `scale = 1/2.5`. Цель: экран/тексель ≤ 0.95 при камере 2.2×1.09.
3. После уменьшения — `AU.unsharp(img, 0.25)`.
4. Попробовать импорт атласа стен Lossless (`compress/mode=0`) и сравнить
   кадр и память (≈ 4096×2048×4 = 32 МБ; если много — оставить BPTC с
   high_quality и проверить глазами).
5. Масштаб ворот и башен — от **родного** размера новой картинки. Не
   растягивать больше 1.0 от размера, под который её печём.
6. Шаг `walls` переписать идемпотентно: искать спрайты по мете `art3`
   (сейчас он ищет старые регионы `town_props_hd`, повторно не сработает).

### Шаг C. Стены без зазоров
1. Секции из бесшовного «кирпича» (промпт 3.1): у картинки ровные вертикальные
   края, верх галереи и низ кладки доходят до края.
2. Обрезка при нарезке: срезать с каждого бока столбцы, где непрозрачно меньше
   85% высоты основного тела. Это гарантирует, что край — сплошная кладка.
3. Ставить секции **внахлёст**: шаг = 0.94 ширины, каждая следующая на 1 px
   ниже по y (y-sort), чтобы нахлёст не мерцал.
4. На каждом 2–3-м стыке — **контрфорс** (промпт 3.4): узкий столб, закрывает
   шов и ломает повтор. Он же — на концах стены у башен и ворот.
5. Проломы: картинка пролома той же высоты и с теми же ровными краями
   (промпт 3.2), чтобы стыковаться с целыми секциями.
6. Боковая стена (`wall_side`, вдоль взгляда): бесшовный вертикальный кусок
   (промпт 3.3), шаг 0.9 высоты.
7. Проверка: скрипт меряет на кадре столбцы прозрачности вдоль линии стены
   (как в `edges.gd` из скретча) — ни одного разрыва шире 2 px.

### Шаг D. Башня у старта и ворота
- Внешние ворота (спавн `(1150, 2530)`) и квадратные башни внешней стены
  заменить на новые картинки из промптов 3.5–3.7.
- Проход под аркой оставить 84 px. Если новая арка шире — `GATE_PASS` по
  картинке (замерить просвет арки по альфе, как сделано в этой сессии).
- Помост захватчиков `siege_platform` у старта уже чёткий (0.99). Если
  «вышка» — это он, допечь его тоже в `TEX_SCALE 2.5`.

### Шаг E. Каменные улицы
1. Исправить `WORLD` в `cobble_road.gd` (и `forest_paths.gd`,
   `build_terrain.gd`) на ширину 9408.
2. Новые плитки (промпты 4.1–4.3) → `cobble_road.gd -- textures`. Срезов
   станет 4: обычная, замшелая, городская разбитая, площадь-плиты. Шейдеру —
   выбор среза по маске: G-канал `cobble_map` = «площадь», шум = «разбитая».
   Это правка `terrain_ground.gdshader` (`cobble_sample`).
3. Новый шаг `streets` в `cobble_road.gd`: маска R рисуется по
   `holmvik_town.gd STREETS` (линии и ширина улиц) + прямоугольник площади +
   переулки из `FREE_RECTS`. Край — тот же мягкий «камни тонут» (шум, BLUR_R).
   Улицы нижнего города — беднее: только по центру полосы, края — грязь.
4. В маске троп (`paths.res` R) городские улицы **погасить** — иначе по
   камню рисуется земля. Тропинки к дверям и дворам оставить землёй.
5. Декали улиц (промпт 4.4): лужи, сажа, выбитые камни, ветки — редко,
   скриптом, на ~10% длины улиц. Не на проходах ворот.
6. Пересобрать: `cull_hidden_ground.gd` (если трогали Stone),
   `normal_bake.gd -- cobble_layers` (TILED), `--import`.

### Шаг F. Проверка
- Скриншоты тех же точек, что в этой сессии (`townshot.gd`):
  `-420 1000 0.36`, `1150 2450 1.0` (старт), `-900 -500 1.0` (северная стена),
  `-1910 1800 1.0` (внутренние ворота), `-1500 900 1.0`, `-300 1050 1.0`.
  Плюс крупно 2.2 у стыков стены.
- Маршрут спавн → внутренние ворота → площадь → верх → арена (`route.gd`).
- Запуск уровня 500 кадров без SCRIPT ERROR.
- Навмеш перепечь во временный файл и скопировать (редактор держит
  `navmesh.res`); сохранение сцены — с повтором при «Can't open».

---

## 3. Промпты: стены (каждый — отдельный новый чат, одна картинка)

Как генерировать:
- **Один предмет на картинку**, квадрат или широкий кадр 1536×1024, предмет
  на ~90% ширины. Именно это убирает мыло: всё разрешение уходит на один
  предмет.
- Приложить `textures/src/hd/refs/holmvik_town_ref.png` (ракурс) и одну
  готовую картинку стены из `props_v3/stone_walls.webp` — **как образец
  стиля и камня** (стиль в этот раз совпадает, его надо удержать).
- Отправить **общий блок + блок предмета**.
- Если вышло мягко: `Sharper, more fine detail in the stones and timber, crisp edges, no blur, no painterly smudging.`

### Общий блок (вставлять перед каждым предметом)

```
Single game asset for a grim dark-fantasy action RPG, high top-down 3/4 camera,
orthographic (no perspective distortion), looking down at about 45-50 degrees,
exactly like the attached reference screenshot (use it ONLY for camera angle).
Match the attached stone wall image EXACTLY in style, stone, timber, colours and
damage: dark grey fieldstone masonry, almost black weathered timber hoarding on
top with a broken shingle roof, soot streaks, moss only in cracks, rust and
dried-blood red accents, overcast light from the top-left.
Very high detail and crisp: every stone and plank sharply defined, no blur, no
soft painterly smudging, no depth of field. Realistic, NOT cartoon, NOT toy-like.
ONE object only, centred, filling about 90% of the image width.
Transparent background (PNG with alpha). No ground, no grass, no shadow on the
ground, no smoke, no fire, no people, no text.
```

### 3.1 `wall_tile` — секция стены, бесшовная по бокам

```
A straight section of the town's stone curtain wall facing the viewer: masonry
wall about 3 hero heights tall with a roofed wooden walkway (hoarding) on top.
IMPORTANT: this piece will be repeated side by side many times, so the LEFT and
RIGHT edges must be perfectly straight vertical cuts through solid masonry and
timber — no crumbled corners, no tapering, no rubble or stones sticking out at
the ends; the wall body, the walkway and its roof all reach both edges at full
height, so the right edge continues seamlessly into the left edge. Light damage
only in the middle (a few missing shingles, soot, one arrow slit), the bottom
edge is a straight line where the wall meets the ground.
Wide format: the section is about 2 times wider than tall.
```

Если получилось с рваными краями — в том же чате:
`The ends are not seamless. Cut both ends straight through the full wall, top to bottom, like a tileable texture strip.`

### 3.2 `wall_tile_breach` — та же секция с проломом, бесшовная по бокам

```
The same straight wall section, same height and same straight seamless left and
right edges (full-height solid masonry at both ends), but in the MIDDLE the wall
has a siege breach: a V-shaped collapsed gap down to about one third of the
height, broken stones and charred beams falling into the gap, the walkway above
it burnt and broken. Both ends must still match the undamaged section exactly.
```

### 3.3 `wall_run` — стена, уходящая вглубь (вдоль экрана вверх)

```
The same stone curtain wall seen running AWAY from the viewer, going straight
up the screen: a narrow vertical strip showing the top of the wall (the roofed
wooden walkway seen from above) and its right-side face. IMPORTANT: the TOP and
BOTTOM edges must be straight horizontal cuts through the full wall, so the
strip tiles seamlessly vertically. Tall format: about 5 times taller than wide.
```

### 3.4 `wall_buttress` — контрфорс / столб (закрывает стыки)

```
A massive stone buttress pillar that stands against the front of the wall: a
narrow square stone pier a little taller than the wall section, with a small
pointed slate cap, slightly wider at the base, soot and moss. Seen from the
front. Narrow format, about 1 to 3 (width to height).
```

### 3.5 `gate_main` — надвратная башня (внешние и внутренние ворота)

```
A big stone gatehouse facing the viewer: two massive round towers with conical
shingle roofs flanking a deep arched gate passage, a raised iron portcullis
inside the arch, the oak gate doors smashed and hanging open, a covered timber
walkway between the towers. The arch opening is clearly visible and goes all
the way down to the ground. The outer sides of both towers end in straight
vertical cuts of plain masonry at the same height as the curtain wall, so the
wall sections join them cleanly. About 2 times wider than tall.
```

### 3.6 `tower_corner` — квадратная угловая башня (у старта и на углах)

```
A square stone corner tower of the town wall, about 1.5 times as tall as the
wall, rough grey fieldstone, arrow slits, the wooden top storey burnt and
partly collapsed with charred beams, a torn dark banner. Seen from the front,
its left and right faces visible at the 3/4 angle.
```

### 3.7 `tower_round` — круглая башня (северная стена)

```
A massive round stone tower of the town wall, about 2 times as tall as the
wall, conical dark shingle roof with a few holes, a ring of arrow slits under
the roof, cracks and soot running down from the slits, a broken wooden hoarding
on one side.
```

### 3.8 `wall_rubble` — завал у пролома (по желанию, нынешний нормальный)

```
A heap of fallen wall stones, broken timber from the walkway and a snapped siege
ladder lying across it, as if poured out of a breach in the wall. Low and wide,
about 3 times wider than tall.
```

---

## 4. Промпты: улицы (плитки на весь кадр)

Как генерировать:
- Квадрат **1254×1254** (как у `road_cobble.webp`), вид **строго сверху**,
  без перспективы, без теней от предметов.
- Приложить нынешний `textures/src/hd/road_cobble.webp` как образец
  масштаба камня (один камень ≈ 1/12 ширины картинки).
- Бесшовность GPT обещает, но шов остаётся. Скрипт `cobble_road.gd` его
  сглаживает, но чем ровнее свет по кадру, тем лучше.

### Общий блок для плиток

```
Seamless tileable ground texture, viewed straight from above (orthographic,
no perspective, no horizon), even overcast light with no strong shadows and no
vignette, uniform brightness over the whole image so it tiles without visible
seams. Grim realistic dark-fantasy look, NOT cartoon. Cold, desaturated
palette: dark grey and blue-grey stone, black mud, ash. Very sharp, crisp
detail, every stone clearly separated by dark gaps. The image fills the whole
square, no border, no transparent areas, no objects, no people, no text.
Same stone size as the attached cobblestone texture (about 12 stones across).
```

### 4.1 `street_cobble_worn` — улица разорённого города

```
Old town street cobblestones of a sacked Norse town: rounded and squarish dark
grey stones of uneven size, worn smooth in the middle, black mud and ash packed
into the gaps, a few stones missing (small muddy holes), scattered soot stains
and a little trampled straw. No grass.
```

### 4.2 `street_cobble_ruts` — разбитая телегами и штурмом

```
The same town cobblestones but badly damaged: two shallow cart ruts running
across, several cracked and sunken stones, more missing stones with puddles of
black muddy water, ash and charred wood splinters in the gaps.
```

### 4.3 `plaza_flagstones` — площадь у ярлова дома

```
Large flat rectangular flagstones of a town square laid in irregular rows, dark
grey with blue-grey tint, some slabs cracked into pieces, a few slabs tilted
and broken by heavy siege stones, soot marks, mud in the joints, faint worn
carved runes on one slab.
```

### 4.4 `street_decals` — лист декалей для улиц (прозрачный фон)

Это **не** плитка: один лист, предметы раздельно, вид строго сверху.

```
A sprite sheet of 8 separate flat ground decals for a cobblestone street, seen
straight from above (orthographic), transparent background (PNG with alpha),
each item separated by empty space, soft irregular edges that fade out:
1. a puddle of dark muddy rainwater between stones;
2. a large black soot and ash stain with a few charred splinters;
3. a patch of knocked-out cobblestones with mud showing;
4. scattered broken roof shingles;
5. a trail of trampled straw and mud;
6. a scorch mark from a fire arrow with burnt arrow shaft;
7. scattered loose cobblestones;
8. a crack running across several stones with a little water.
Dark, desaturated, realistic. No blood, no bodies, no text.
```

---

## 5. Куда класть и что сказать мне

- Стены: `reference_map_level/textures/src/hd/props_v4/<имя>.png`
  (`wall_tile`, `wall_tile_breach`, `wall_run`, `wall_buttress`, `gate_main`,
  `tower_corner`, `tower_round`, по желанию `wall_rubble`).
- Улицы: `reference_map_level/textures/src/hd/roads_v2/<имя>.png`
  (`street_cobble_worn`, `street_cobble_ruts`, `plaza_flagstones`,
  `street_decals`).
- В новой сессии достаточно написать: «арт для стен и улиц лежит, делай по
  `reference_map_level/NEXT_SESSION_WALLS_ROADS.md`».
- Если какой-то картинки нет — шаги B–D работают по тем, что есть. Вместо
  недостающих остаются нынешние из `props_v3`.
