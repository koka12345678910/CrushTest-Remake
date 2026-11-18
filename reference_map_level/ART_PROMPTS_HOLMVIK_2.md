# Хольмвик — промпты, партия 2 (всё, чего не хватает разорённому городу)

## Как генерировать

- Один раздел = один **новый** чат в GPT.
- К каждому запросу приложи две картинки из `reference_map_level/textures/src/hd/refs/`:
  - `holmvik_town_ref.png` — площадь из игры с новыми домами (стиль, ракурс, масштаб);
  - `holmvik_scale_ref.png` — Хальвард у двери дома (рост героя).
- Скопируй **весь** серый блок и отправь.
- Это листы: несколько предметов на одной картинке. Если GPT слепил предметы
  вместе, допиши в том же чате:
  `Same sheet, but every item fully separated by empty transparent space, nothing overlapping.`
- Если появилась земля или фон:
  `Same sheet, but on a fully transparent background, no ground, no grass.`
- Результаты клади в `reference_map_level/textures/src/hd/props_v2/` с именем из
  заголовка (например, `dark_sun.png`). Нарезку и расстановку сделаю я.

Порядок по важности: 1 → 3 → 4 → 5 → 6 (раздел 2 генерировать НЕ нужно — см. ниже).

---

## 1. dark_sun — знаки Ордена Тёмного Солнца

```
A sprite sheet of 6 separate items for a dark-fantasy action RPG, laid out in
a grid with plenty of empty space between them.
Camera: high top-down 3/4 view, orthographic, looking down at about 45-50
degrees, exactly like the attached reference screenshots.
Style: painterly realism, richly detailed hand-painted textures, muted dark
palette, soft overcast light from the top-left, no cast shadow on the ground.
Setting: medieval Scandinavia, 11th-12th century. The invaders are a fanatical
order called the Order of the Dark Sun. Their sigil: a BLACK SUN DISC (an
eclipse) with a thin ring of dull blood-red corona and long jagged black rays.
Their colours: black, charcoal and dull blood-red, with rusted iron.
Items:
1. a tall war standard: black cloth banner with the sigil on a crossbar, the
   pole driven into the ground, ragged edges, 3 hero heights tall;
2. a long black banner hanging from a wooden beam (to nail over a doorway),
   the sigil in the middle, torn bottom edge, 2 hero heights tall;
3. a spear stuck in the ground with a small black pennant with the sigil;
4. a round wooden shield painted black with the sigil, nailed to a post;
5. a rough iron brazier on three legs, cold black ash, the sigil forged on
   its side, 1 hero height tall;
6. a crude altar of stacked stones with a black-painted sun disc on top, melted
   black candles and soot, 1 hero height tall.
Output: transparent background (PNG with alpha), no ground plane, no people,
no text or letters, nothing modern.
Scale: the hero in the reference screenshot is 1 unit tall.
```

## 2. fallen — павшие (НЕ генерировать)

Павшие — это персонажи, а персонажи в игре пиксельные (герои, враги). Рисованные
GPT тела рядом с пиксельным Хальвардом выглядели бы чужеродно. Их соберу сам из
последних кадров анимаций смерти, которые уже есть в проекте (8 направлений у
каждого персонажа), с перекраской: горожане — в шерсть и холст (бурый, охра,
серый), стража Бальдра — из рыцаря Knight_Character в бело-золотом.

## 3. barricades — завалы на улицах (вместо нынешних куч ящиков)

```
A sprite sheet of 5 separate items for a dark-fantasy action RPG, laid out in
a grid with plenty of empty space between them.
Camera: high top-down 3/4 view, orthographic, looking down at about 45-50
degrees, exactly like the attached reference screenshots.
Style: painterly realism, muted autumn palette, soft overcast light from the
top-left, no cast shadow on the ground.
Setting: a medieval Scandinavian town; the defenders blocked the streets with
whatever they had, and the raiders broke through days ago.
Items (each is a barrier ACROSS a street, wide and low, clearly impassable):
1. an overturned cart with barrels and sacks piled against it, 4 hero heights wide;
2. a wall of planks, doors and benches nailed to posts, partly scorched,
   4 hero heights wide;
3. a heap of broken furniture, crates, a wheel and a table on its side,
   3 hero heights wide;
4. a collapsed burnt roof beam with fallen shingles and rubble,
   4 hero heights wide;
5. a short line of sharpened stakes (cheval-de-frise) tied with rope,
   3 hero heights wide.
Output: transparent background (PNG with alpha), no ground plane, no people,
no text, nothing modern.
Scale: the hero in the reference screenshot is 1 unit tall.
```

## 4. yard — дворы и быт

```
A sprite sheet of 8 separate items for a dark-fantasy action RPG, laid out in
a grid with plenty of empty space between them.
Camera: high top-down 3/4 view, orthographic, looking down at about 45-50
degrees, exactly like the attached reference screenshots.
Style: painterly realism, muted autumn palette, soft overcast light from the
top-left, no cast shadow on the ground.
Setting: backyards of a medieval Scandinavian town, abandoned a few days ago.
Items:
1. a wooden well with a small shingle roof, a crank and a bucket on a rope,
   2 hero heights tall;
2. a long woodpile of split logs under a small lean-to roof, 3 hero heights wide;
3. a laundry line between two posts with wool shirts and linen hanging,
   one shirt fallen on the ground, 3 hero heights wide;
4. a vegetable garden bed with cabbages and onions, trampled, with a low
   wattle border, 3 hero heights wide;
5. a fish drying rack with split cod hanging, 2 hero heights wide;
6. a chopping block with an axe stuck in it and wood chips around;
7. a rain barrel under a wooden gutter spout;
8. a small wooden goat pen with a broken gate, empty, 2 hero heights wide.
Output: transparent background (PNG with alpha), no ground plane, no people,
no animals, no text, nothing modern.
Scale: the hero in the reference screenshot is 1 unit tall.
```

## 5. palisade — частокол и ворота города

```
A sprite sheet of 5 separate items for a dark-fantasy action RPG, laid out in
a grid with plenty of empty space between them.
Camera: high top-down 3/4 view, orthographic, looking down at about 45-50
degrees, exactly like the attached reference screenshots.
Style: painterly realism, muted autumn palette, dark weathered timber,
soft overcast light from the top-left, no cast shadow on the ground.
Setting: the defensive wall of a medieval Scandinavian town: a palisade of
sharpened logs with a walkway behind it.
Items:
1. a straight palisade section facing the viewer, 4 hero heights wide,
   3 hero heights tall, seamless on the left and right edges so sections can
   be placed side by side;
2. the same section damaged: a few logs broken and burnt;
3. a palisade section seen running AWAY from the viewer (the wall goes up the
   screen): a narrow vertical strip of log tops and the side of the logs,
   seamless at the top and bottom edges, 6 hero heights long;
4. a square timber corner tower with a roofed lookout, 3 hero heights wide;
5. a big town gatehouse facing the viewer: a timber tower over a gate passage,
   heavy double doors (one door broken and hanging), a roofed walkway on top,
   dragon-head finials, 6 hero heights wide.
Output: transparent background (PNG with alpha), no ground plane, no people,
no text, nothing modern.
Scale: the hero in the reference screenshot is 1 unit tall.
```

## 6. temple_steps — вход в арену у храма

```
A sprite sheet of 3 separate items for a dark-fantasy action RPG, laid out in
a grid with plenty of empty space between them.
Camera: high top-down 3/4 view, orthographic, looking down at about 45-50
degrees, exactly like the attached reference screenshots.
Style: painterly realism, muted palette, grey fieldstone and dark timber,
soft overcast light from the top-left, no cast shadow on the ground.
Setting: the sacred courtyard in front of the Temple of Baldr's Light,
desecrated by the Order of the Dark Sun (black sun sigil: a black disc with a
dull red corona).
Items:
1. a carved stone gateway to the courtyard: two stone pillars with golden sun
   discs and a timber lintel with dragon heads, the passage 3 hero heights
   wide, a black banner with the black sun nailed across the lintel;
2. a low carved stone courtyard wall section facing the viewer, 4 hero heights
   wide, seamless on the left and right edges;
3. a toppled stone statue of a radiant young god (Baldr) lying on the ground,
   face smeared with soot, 3 hero heights long.
Output: transparent background (PNG with alpha), no ground plane, no people,
no text, nothing modern.
Scale: the hero in the reference screenshot is 1 unit tall.
```

---

## Что сделаю сам, без арта

- **Туман у входа в арену** (как в Dark Souls) — шейдером.
- **Кровь и пятна копоти** — уже есть в атласе лагеря, расставлю рядом с павшими.
- **Интерьеры домов** — отдельная партия позже, когда будет понятно, какие дома
  открываются.
