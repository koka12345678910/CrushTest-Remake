# Хольмвик — промпты, партия 4: завалы, заглушки проходов, прорывы

Зачем: игрок не понимает, куда идти и где можно пройти. Сейчас завалы — низкие
бурые кучки ниже роста героя, ночью сливаются с мостовой; линии баррикад — это
невидимые стены через дворы; щели между домами то проходимы, то нет, и по виду
этого не понять. Правило новой карты: **закрыто — видно издалека, открыто —
видно тоже**. Каждая невидимая стена заменяется артом, которого хватает на всю
её ширину.

Что меняется по сравнению с партией 2 (`props_v2/barricades.webp`):
- завалы **выше героя** (2–2.5 роста) — сверху читаются как стена, а не мусор;
- **во всю ширину улицы** (улица ≈ 3 роста героя) и с краями, которые
  «упираются» в стены домов;
- светлые и тёмные пятна в силуэте (белёсое дерево сломов, пепел, ткань) —
  чтобы ночью при луне и огне контур не тонул;
- отдельные **заглушки щелей** между домами (1–2.5 роста шириной);
- **прорванные** завалы для пути героя: сразу видно, что здесь прошли.

## Как генерировать

- Один раздел = один **новый** чат. Приложи `holmvik_town_ref.png` и
  `holmvik_scale_ref.png` из `reference_map_level/textures/src/hd/refs/`
  (ракурс и масштаб) и **не** проси повторять их стиль: стиль задаёт текст.
- Скопируй **общий блок + блок раздела** (оба блока подряд) и отправь.
- Результаты клади в `reference_map_level/textures/src/hd/props_v4/`,
  имя файла — из заголовка раздела (`barricades_v2.png` и т. д.).
- Если вышло «мультяшно» — допиши в том же чате:
  `Too clean and toy-like. Make it grim, heavy, realistic: irregular shapes, heavy
  weathering, soot, mud, broken parts, darker and colder palette.`
- Если вышло низко и плоско — допиши:
  `Make every barricade much TALLER: at least 2 hero heights, a wall you cannot
  see over, with a jagged top silhouette.`

## Общий блок стиля (вставлять перед каждым разделом)

```
Game assets for a grim dark-fantasy action RPG, seen from a high top-down 3/4
camera, orthographic (no perspective distortion), looking down at about 45-50
degrees: the front faces the viewer and tops are clearly visible, exactly like
the attached reference screenshots (use them ONLY for camera angle and scale).
Art direction: grim, heavy, realistic dark-fantasy concept art, painterly but
NOT cartoon, NOT stylized, NOT toy-like, NOT a mobile-game look. Realistic
proportions, irregular and asymmetric, heavy and chaotic. Heavy weathering:
soot, mud, charred wood, rain stains.
Palette: cold and desaturated — near-black charred timber, ash grey, dark
blue-grey stone, with LIGHT accents that keep the silhouette readable at night:
pale freshly split wood at every break, grey-white ash, bleached cloth, rusted
iron. Small accents of dried-blood red.
Light: overcast, dim, from the top-left; deep shadows inside the piles.
Setting: a Norse regional town (11th-12th century). The town guard blocked the
streets with everything they had; a fanatical order (black eclipse sun with a
blood-red corona on its banners) broke through a few days ago and holds the
town now.
Output: transparent background (PNG with alpha), each item fully separated by
empty transparent space, no ground plane, no grass, no people, no corpses, no
text, nothing modern. Scale: the hero in the reference screenshot is 1 unit tall.
```

---

## 1. barricades_v2 — завалы поперёк улиц (закрыто)

Ставятся там, где улица закрыта. Края упираются в дома — по краям можно
оставить «рваные» концы, их закроют стены домов.

```
A sprite sheet of 6 separate items: street barricades that completely block a
street. Each is a wall of junk ACROSS the street: about 4 hero heights wide,
2 to 2.5 hero heights TALL (you cannot see over it), with a jagged, readable
top silhouette and a solid, dense base with no gaps to walk through. The
front faces the viewer, the top of the pile is visible.
1. an overturned heavy wagon on its side with a second cart stacked on it,
   doors, barrels and grain sacks rammed in the gaps, a torn bleached sail
   thrown over the top;
2. a tall wall of doors, shutters, tables and benches nailed to thick posts
   dug into the street, braced from behind with diagonal beams, charred along
   the bottom, a black eclipse-sun banner of the order nailed over it;
3. a burning barricade: the same kind of junk wall, its middle still on fire
   (low orange flames and glowing embers inside, thick dark smoke is NOT
   needed), the wood around the fire charred black with grey ash;
4. the collapsed front of a burnt house fallen across the street: a whole
   timber wall frame lying on a heap of stones and roof beams, shingles,
   a chimney broken in two;
5. a double row of sharpened stakes (cheval-de-frise) higher than a man,
   lashed with rope, with planks and a broken cart wedged between them;
6. a heap of stone rubble from a breached wall: big squared blocks, broken
   timber hoarding and a smashed siege ladder, as tall as two men.
```

## 2. alley_closers — заглушки щелей между домами (закрыто, но узко)

Щели между стоящими вплотную домами — от 1 до 2.5 роста героя. Сейчас там
невидимая коллизия или вообще проход, о котором игрок не догадается.

```
A sprite sheet of 7 separate items that close the narrow gap BETWEEN two
houses standing close together. Each item is tall (about 2 hero heights) and
narrow, its left and right edges are straight and plain so it fits snugly
against house walls. The front faces the viewer.
1. a tall plank fence with a closed, barred wooden gate in it, 1.5 hero
   heights wide;
2. a tall wattle (woven branch) fence between two posts, sagging, 2 hero
   heights wide;
3. firewood stacked as high as a man between two posts, with a small
   shingle roof over it, 1.5 hero heights wide;
4. a lean-to shed built into the gap: plank walls, sloped shingle roof,
   a barrel and tools at its front, 2.5 hero heights wide;
5. a heap of barrels, crates and sacks stacked to the height of a man,
   tied with rope, 1.5 hero heights wide;
6. a burnt plank fence, half collapsed but still blocking, charred black
   with pale split ends, 2 hero heights wide;
7. a narrow stone wall with a small arched doorway bricked up with fresh
   stones, 1 hero height wide.
```

## 3. breaches — прорванные завалы (открыто: путь героя)

Ставятся там, где улица ОТКРЫТА — особенно на линиях баррикад, где сейчас
незаметный «проход в стене». Игрок должен сразу видеть: тут прорвались, тут
путь.

```
A sprite sheet of 5 separate items: barricades that were BROKEN THROUGH by an
attacking army. Each one is split into two parts with a clear, wide gap in the
middle (at least 2 hero heights wide) where the junk was smashed and pushed
aside; trampled debris, broken planks and dropped shields lie in the gap,
pointing the way through. Total width about 5 hero heights, the side parts
2 hero heights tall. The front faces the viewer.
1. the overturned-wagon barricade smashed open: the wagon pulled aside and
   broken in two, barrels rolled away;
2. the plank-and-door wall with its middle hacked down by axes, splintered
   pale wood, a fallen door lying flat in the gap;
3. a gate of sharpened stakes with the middle stakes cut and dragged aside,
   ropes hanging loose;
4. a burnt barricade whose middle has burned down to a low black line of
   embers and ash that can be stepped over, the sides still standing;
5. a town-guard shield wall that failed: a row of round wooden shields with a
   golden sun painted on them (the god of light), broken spears stuck in the
   ground, the middle shields knocked flat.
```

## 4. trail — след стражи Бальдра (по желанию, для наратива)

Мелкие вещи, по которым видно, куда отступали защитники города — к храму.
Персонажей и тел тут нет (тела — пиксельные, их собираю сам).

```
A sprite sheet of 8 small separate items left behind by the retreating town
guard of the sun god Baldr (round wooden shields with a golden sun, white and
gold tabards), each about 1 hero height or smaller:
1. a dropped round shield with a golden sun, split, lying flat;
2. a broken spear and a helmet lying on the ground;
3. a torn white-and-gold banner with a sun, its pole snapped, lying flat;
4. a small roadside shrine of Baldr: a stone post with a carved sun disc and
   a lit oil lamp, 1.5 hero heights tall;
5. the same shrine knocked over and smashed, the lamp spilled;
6. a wooden signpost with a carved sun symbol on its single arm (no letters);
7. a dark trail of dragged blood on stone, long and narrow, 3 hero heights
   long (seen from above, flat on the ground);
8. a stake with a black eclipse-sun banner of the order, freshly planted over
   a pile of the guard's shields.
```

---

## Что сделаю сам, когда арт будет готов

- Все линии баррикад перестрою: коллизия — только там, где стоит арт, и арт
  закрывает всю ширину каждого прохода. Невидимых стен не останется.
- Щели между домами: проходимые оставлю только там, где за ними что-то есть
  (сундук, переулок к цели) и подсвечу их фонарём; остальные закрою
  заглушками из раздела 2.
- На пути героя — прорванные завалы из раздела 3, на закрытых улицах —
  целые из раздела 1, с огнём или знаменем Ордена.
