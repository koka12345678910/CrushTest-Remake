# Хольмвик — промпты, партия 3: каменный город и война

Что не так с нынешним артом (ваш отзыв): «всё по-детски». Причина — GPT рисует
игрушечно: чистые, симметричные, пропорции «домик из мультика», ровный бурый
цвет, мягкий свет. Этот блок прямо запрещает такое и задаёт мрачный реализм.

## Как генерировать

- Один раздел = один **новый** чат. Приложи `holmvik_town_ref.png` и
  `holmvik_scale_ref.png` из `reference_map_level/textures/src/hd/refs/`
  (ракурс и масштаб) — и **не** проси повторять их стиль: стиль задаёт текст.
- Скопируй **общий блок + блок раздела** (оба серых блока подряд) и отправь.
- Результаты клади в `reference_map_level/textures/src/hd/props_v3/`
  (дома — в `houses_v3/`), имя — из заголовка.
- Если вышло снова «мультяшно» — допиши в том же чате:
  `Too clean and toy-like. Make it grim, heavy, realistic: irregular shapes, heavy
  weathering, soot, mud, broken parts, darker and colder palette.`

## Общий блок стиля (вставлять перед каждым разделом)

```
Game assets for a grim dark-fantasy action RPG, seen from a high top-down 3/4
camera, orthographic (no perspective distortion), looking down at about 45-50
degrees: the front faces the viewer and roofs/tops are clearly visible, exactly
like the attached reference screenshots (use them ONLY for camera angle and scale).
Art direction: grim, heavy, realistic dark-fantasy concept art, painterly but
NOT cartoon, NOT stylized, NOT toy-like, NOT a mobile-game look. Realistic
proportions and real masonry/timber construction, irregular and asymmetric,
sagging and uneven. Heavy weathering: soot streaks, rain stains, mud splashes,
moss only in cracks, scorched and charred wood, broken shingles, collapsed parts.
Palette: cold and desaturated — dark grey and blue-grey stone, almost black
weathered timber, ash and soot, small accents of rust and dried-blood red.
Light: overcast, dim, from the top-left; deep shadows; no bright sunny colours.
Setting: a Norse regional town (11th-12th century) that was besieged and sacked
by a fanatical order a few days ago: siege damage, fires still smouldering.
Output: transparent background (PNG with alpha), each item fully separated by
empty transparent space, no ground plane, no grass, no people, no corpses, no
text, nothing modern. Scale: the hero in the reference screenshot is 1 unit tall.
```

---

## 1. stone_walls — каменные стены города (вместо частокола)

```
A sprite sheet of 7 separate items: the stone curtain wall of the town.
1. a straight stone curtain wall section facing the viewer, 4 hero heights
   wide, 3 hero heights tall, rough grey fieldstone with timber hoarding
   (a roofed wooden walkway) on top, seamless on the left and right edges;
2. the same section damaged by siege: a breach with collapsed stones, the
   hoarding burnt, scorch marks;
3. the same wall seen running AWAY from the viewer (going up the screen):
   a narrow vertical strip showing the wall top and its side, seamless at the
   top and bottom edges, 6 hero heights long;
4. a massive round stone tower with a conical shingle roof, arrow slits,
   4 hero heights wide;
5. a square stone corner tower with a burnt, partly collapsed wooden top,
   3 hero heights wide;
6. a big stone gatehouse facing the viewer: two round towers flanking a deep
   arched gate passage with a raised iron portcullis and smashed oak doors,
   a covered walkway between the towers, 7 hero heights wide;
7. a pile of fallen wall stones and a broken siege ladder (rubble at a breach),
   3 hero heights wide.
```

## 2. houses_v3 — дома в 3 этажа, камень + дерево

Новый чат на каждый дом. После вида спереди в том же чате — «боком» и «задом»
(тексты в `ART_PROMPTS_HOLMVIK.md`, раздел «Повороты»).

```
A single building: a tall three-storey town house of a rich Norse regional
town. Heavy stone ground floor (grey fieldstone, deep-set door and small
barred windows), two timber upper floors that jut out over the street, a steep
dark shingle roof with a stone chimney. Narrow and tall, squeezed between
neighbours (its side walls are plain, no windows). Siege damage: a hole in
the roof from a catapult stone, burnt shutters, soot above the windows,
a smashed door. About 6 hero heights wide.
```

Ещё варианты (тот же блок, меняется описание):

- `townhouse_stone_wide` — `a wide two-storey stone house with a timber gallery
  on the upper floor and an outside stone staircase, roof partly burnt through,
  about 8 hero heights wide.`
- `guildhall` — `a large stone guild hall with a steep roof, a carved wooden
  porch on heavy pillars, iron-bound double doors broken in, banners torn down,
  about 10 hero heights wide.`
- `stone_longhouse` — `a long low stone-walled longhouse with a heavy turf roof,
  half of the roof collapsed and still smouldering, about 10 hero heights wide.`
- `burnt_shell` — `the burnt-out stone shell of a three-storey house: walls
  still standing, black windows, roof and floors gone, charred beams, smoke
  rising, about 6 hero heights wide.`
- `tower_house` — `a narrow fortified stone tower-house, four storeys, arrow
  slits, a wooden hoarding on top, scorched, about 4 hero heights wide.`

## 3. siege — следы осады и войны

```
A sprite sheet of 10 separate items:
1. a heavy wooden battering ram on wheels with an iron head, abandoned;
2. a broken ballista with a snapped bow arm;
3. two large catapult stones half-sunk in the ground, with cracked cobbles;
4. a burnt-out cart with smouldering cargo;
5. a heap of charred beams and roof shingles still smoking;
6. a row of sharpened stakes with torn black banners of the invaders
   (black sun disc with a dull red corona) — a camp marker;
7. a toppled stone statue of a Norse warrior, broken in two;
8. a pile of broken shields, spears and helmets (no bodies);
9. a well with its roof burnt, a black banner thrown over it;
10. a hastily built wooden watch platform of the invaders, with a black sun banner.
Each about 2-4 hero heights wide.
```

---

## Что я сделаю, когда придёт арт

- Каменные стены заменят частокол целиком: башни на углах и через равные
  промежутки, каменные ворота-башни внутренних и внешних ворот, пролом-пролом
  со стенами-обломками у завалов.
- Дома v3 встанут в улицы вместо части нынешних: на главной и северной улицах —
  трёхэтажные каменные (плотные ряды «стена к стене»), бедные деревянные —
  на окраинах и в нижнем городе.
- Осада: таран у внешних ворот, камни катапульт в проломах и на площади,
  сгоревшие телеги, лагерные знамёна Ордена на площади.
