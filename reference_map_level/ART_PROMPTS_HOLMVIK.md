# Хольмвик — промпты для новых зданий (партия 1)

Хольмвик — областной центр Скальдхейма, городок, а не деревня. Его разорил Орден
Тёмного Солнца **несколько дней назад**: дома крепкие и жилые, но со свежими
следами налёта. Мха, гнили и старых руин быть не должно — иначе непонятно, когда
всё случилось.

## Как генерировать

1. Одно здание — один запрос.
2. К каждому запросу приложи две картинки из `reference_map_level/textures/src/hd/refs/`:
   - `holmvik_scale_ref.png` — кадр из игры: герой у двери таверны (масштаб и ракурс);
   - `holmvik_angle_ref.png` — нынешние дома (только ракурс и манера рисования, НЕ их ветхость).
3. Текст запроса = **общий блок** + **блок здания**. Оба на английском (так генератор
   точнее держит ракурс и прозрачный фон).
4. Если на картинке появилась земля, трава или фон — попроси переделать:
   `Same building, but on a fully transparent background, no ground, no grass.`
5. Готовые PNG клади в `reference_map_level/textures/src/hd/houses_v2/` с именем
   из заголовка (например, `temple_baldr.png`). Дальше атлас и расстановку делаю я.

## Повороты

Не все дома смотрят дверью в камеру: часть стоит боком или задом — камера та же
(high top-down 3/4), повёрнут только дом. Поворот — только на 90° и 180° (коллизия
домов прямоугольная, диагональ не сядет). «Боком вправо» генерировать не нужно: это
зеркало «боком влево», делается в движке.

Порядок: сначала вид спереди (основной запрос), потом **в том же чате** — запрос
поворота (так GPT держит тот же дом, материалы и повреждения). Имена файлов:
`townhouse_a.png` (спереди), `townhouse_a_side.png` (боком), `townhouse_a_back.png` (задом).

Какие повороты у какого здания:

| Здание | Повороты |
|---|---|
| temple_baldr, jarl_hall, watchtower | только спереди (ориентиры / симметричная башня) |
| mead_hall, market_hall, smithy, house_burnt_v2 | спереди, боком |
| merchant_a, merchant_b, townhouse_a, townhouse_b, longhouse_v2 | спереди, боком, задом |

Запрос «боком» (в том же чате, после вида спереди):
```
Now draw the SAME building - same design, materials, colours and damage - but
rotated 90 degrees on the ground, so that its front facade with the main door
faces LEFT and the viewer looks at its side wall. The camera does not move:
same high top-down 3/4 orthographic view, roof clearly visible from above, same
scale and lighting from the top-left. Transparent background, no ground.
```

Запрос «задом» (в том же чате):
```
Now draw the SAME building - same design, materials, colours and damage - but
turned around 180 degrees, so that its back wall faces the viewer and the main
door is on the far side, not visible. Show back-yard details instead: a small
back door or window, a woodpile, a rain barrel, a broken fence. The camera does
not move: same high top-down 3/4 orthographic view, roof clearly visible from
above, same scale and lighting from the top-left. Transparent background,
no ground.
```

## Общий блок (вставлять в каждый запрос)

```
Single isolated building, game asset for a dark-fantasy action RPG.
Camera: high top-down 3/4 view, orthographic (no perspective distortion),
looking down at about 45-50 degrees: the front facade faces the viewer and the
roof is clearly visible from above, exactly like the attached reference screenshots.
Style: painterly realism, richly detailed hand-painted textures, muted autumn
palette (weathered dark timber, grey fieldstone, dull ochre, faded red),
soft overcast light from the top-left, no cast shadow on the ground.
Setting: medieval Scandinavia, 11th-12th century, a prosperous regional town:
massive log and plank walls, tall steep shingle roofs or turf roofs, carved
dragon-head gable finials, interlace wood carvings, heavy stone foundations.
Story state: the town was raided only a few days ago. The building is solid and
was lived in until recently, but shows FRESH damage: a smashed or hacked door,
soot and scorch marks, a few torn-off shingles, arrows stuck in the planks,
spilled barrels. NO moss, NO rot, NO old collapsed ruin look.
Output: transparent background (PNG with alpha channel), the whole building in
frame with a small margin, no ground plane, no grass, no people, no corpses,
no text or letters, nothing modern (no glass windows, no metal pipes,
no modern shoe prints).
Scale: the hero in the reference screenshot is 1 unit tall; doors are about
1.3 units tall.
```

## Здания

Ширина — в ростах героя (в игре герой ~45 px, значит 8 ростов ≈ 360 px мира).

### temple_baldr — Храм Света Бальдра (цель, босс внутри) — ~11 ростов
```
The Temple of Baldr's Light: the largest and holiest building of the town.
A tall Norse stave-church-like temple with three stacked roof tiers, each with
carved dragon finials, on a broad grey stone plinth with wide stone steps
leading up to massive double doors. Above the doors, a large carved golden-white
sun disc with rays (symbol of Baldr), and smaller sun motifs on the gables.
Two cold iron braziers flank the steps. Damage: the great doors are forced open
and hacked, the sun disc is smeared with black soot, a black banner with a
dark eclipsed sun (the invaders' sign) is nailed over the entrance.
Width about 11 hero heights.
```

Доработка храма (в том же чате, если вышел узким и «лёгким»; тон и яркость
подгоняются при импорте — перегенерировать ради цвета не нужно):
```
Make the SAME temple far more massive and imposing - the greatest building of
the whole region, a place that commands awe:
- broad, heavy proportions: about 1.5 times WIDER than it is tall, not a narrow
  spire; a long nave stretching back, its huge roof clearly visible from above;
- lower side aisles / wings with their own roofs on both sides of the nave;
- a tall stone terrace (about 1.5 hero heights) with a wide monumental
  staircase, thick corner buttresses and heavy round wooden pillars;
- huge entrance doors, about 2.5 hero heights tall;
- camera a bit higher and more top-down than before, so the depth of the
  building and the length of its roofs read clearly;
- darker and more sombre: almost black weathered timber, dark grey stone,
  tarnished dull gold on the sun discs, low saturation, deep shadows.
Keep: the soot-smeared sun disc, the black eclipsed-sun banner over the doors,
the broken doors, the dragon finials, the burning braziers, transparent
background, no ground. Width about 15 hero heights.
```

### jarl_hall — Ярлов дом (площадь, главный ориентир города) — ~12 ростов
```
The jarl's great hall: a long, very wide and tall Norse longhall with gently
curved roof ridge and walls, heavy carved wooden pillars along a covered front
porch, a big carved double door in the middle, shields hanging under the eaves,
dragon-head finials on both gables. Damage: shields knocked down and split,
door broken in, one end of the roof scorched.
Width about 12 hero heights.
```

### mead_hall — Медовый зал / таверна — ~8 ростов
```
A two-storey mead hall / tavern: log ground floor, plank upper floor with a
small balcony, a hanging wooden sign shaped like a drinking horn, benches and
barrels by the door. Damage: sign hanging by one chain, benches overturned,
barrels smashed, door hacked.
Width about 8 hero heights.
```

### market_hall — Крытые торговые ряды — ~9 ростов
```
An open-sided covered market hall: a long timber roof on rows of carved
wooden posts, wooden counters and stalls underneath with baskets, cloth bolts,
fish racks and pottery. Damage: stalls toppled, goods scattered, one awning
torn, a post scorched.
Width about 9 hero heights.
```

### merchant_a — Купеческий дом, вариант A — ~5 ростов
```
A narrow, tall three-storey merchant house in Norwegian wharf (Bryggen) style:
gable end facing the viewer, vertical plank walls, small shuttered windows,
a hoist beam with a pulley at the top gable, a storage door on the upper floor.
Damage: shutters torn off, crates spilled from the storage door.
Width about 5 hero heights.
```

### merchant_b — Купеческий дом, вариант B — ~6 ростов
```
A two-storey merchant house with a stone ground floor (shop) and a timber upper
floor overhanging it, a wide shop counter window with folded shutters, a small
carved sign above the door. Damage: counter smashed, door broken, soot above
the window.
Width about 6 hero heights.
```

### townhouse_a — Горожанский дом с галереей, вариант A — ~6 ростов
```
A two-storey log townhouse with an open wooden gallery (svalgang) running along
the upper floor, steep shingle roof, carved railing, a small stair up to the
gallery. Damage: part of the railing broken, door hacked.
Width about 6 hero heights.
```

### townhouse_b — Горожанский дом, вариант B — ~7 ростов
```
A sturdy two-storey log townhouse with a turf roof, a stone chimney, a covered
porch on two posts and a woodpile by the wall. Damage: woodpile scattered,
a few turf blocks torn off, scorch marks by the door.
Width about 7 hero heights.
```

### longhouse_v2 — Жилой длинный дом — ~9 ростов
```
A long low Norse residential longhouse with a thick turf roof, timber walls on
a stone footing, smoke hole in the roof ridge, a single door in the long side
facing the viewer. Damage: door kicked in, a scorched patch on the roof.
Width about 9 hero heights.
```

### smithy — Кузня — ~7 ростов
```
A blacksmith's workshop: a log house with an attached open-sided forge shed,
a stone forge with a cold hearth, bellows, an anvil on a stump, tool racks
and a quenching barrel. Damage: tool rack knocked over, anvil toppled.
Width about 7 hero heights.
```

### watchtower — Сторожевая башня — ~4 роста
```
A tall square timber watchtower, three storeys, on a stone base, with a roofed
lookout platform on top and a ladder. Damage: lookout railing broken, a few
arrows stuck in the planks.
Width about 4 hero heights.
```

### house_burnt_v2 — Сгоревший дом — ~6 ростов
```
A two-storey Norse timber house burned down only days ago: charred black
beams, collapsed roof section, walls blackened by smoke, faint glowing embers
in the rubble, but the stone foundation and chimney still standing.
Fresh destruction, not an old ruin: no moss, no plants growing.
Width about 6 hero heights.
```

## Следующие партии (позже)

- Ворота городка (фронтальная надвратная башня) и частокол: секция фронтальная,
  секция «вдоль взгляда», угловая башня.
- Баррикады для завалов на улицах, трупы горожан, знамёна Ордена Тёмного Солнца,
  фонари на столбах, колодец, телеги.
- Интерьеры домов с лутом (по образцу кладбища) и интерьер храма с ареной босса.
