# Хольмвик — промпты, партия 6: жилые дома города

## Почему нынешние дома не подходят

Если поставить рядом дом из партии 1 (`houses_v2/townhouse_a.png`) и постройку
из партии 5 (`props_v5/yard_buildings.webp`), разница сразу видна. Постройки
партии 5 легли в город хорошо — с них и берём стиль.

1. **Другой стиль.** Дома партии 1 — чистые, тёплые, рыже-коричневые,
   «пластиковые»: одинаковая черепица, ровные брёвна, всё блестит. Всё
   остальное в городе (стены, завалы, дворы, постройки партии 5) — тёмное,
   холодное, потёртое, с грязью и сажей. Дом выглядит игрушкой среди
   настоящих вещей. Причина — в промпте партии 1 было «без мха, без гнили»:
   генератор понял это как «новенький».
2. **Смесь архитектуры.** Норвежские срубы с драконами, немецкие фахверковые
   трёхэтажки и английская каменная часовня стоят в одном ряду. Город не
   читается как одно место.
3. **Слишком высокие.** Трёхэтажные дома нависают над улицами и закрывают
   их, герой рядом выглядит гномом.
4. **Вещи приклеены к дому.** Бочки, мешки и ящики нарисованы прямо у стены.
   В игре они торчат на улицу, перекрывают коллизию, и их нельзя убрать
   или разбить. Вещи у домов я ставлю сам (а дворы уже обставлены).
5. **Драконьи головы на каждом доме.** На всех домах они превращаются в
   украшательство. Пусть будут только у богатых и больших.

## Что делаем

Один стиль и одна архитектура для всего жилого города: **норвежский торговый
городок XI–XII века**:
- срубы и дощатые дома на каменном цоколе;
- крутые крыши из дранки или дёрна;
- узкие окна со ставнями, без стекла;
- галереи на столбах, хозяйственные амбары на сваях;
- камень — только цоколь и печные трубы, у богатых домов — первый этаж.

Высота — 1–2 этажа, редко с мансардой. Рисовать так же, как постройки
партии 5: тёмное дерево, холодный свет, грязь, сажа, свежие следы налёта.

Заменяются все рядовые дома (townhouse, merchant, longhouse, сгоревшие —
около 80 домов в городе). Храм Бальдра, ярлов дом, стены и башни остаются —
если они тоже выбиваются, скажи, сделаю отдельную партию.

## Как генерировать

- Приложи к **каждому** чату две картинки из
  `reference_map_level/textures/src/hd/refs/`:
  - `holmvik_buildings_style_ref.webp` — постройки партии 5: **образец стиля**
    (материалы, цвет, грязь, свет). Это главный референс;
  - `holmvik_style_v6_ref.png` — кадр из игры: ракурс, масштаб, как постройки
    стоят в городе рядом с героем.
- Один дом — один **новый** чат: сначала вид спереди (общий блок + блок дома),
  потом в том же чате повороты (запросы ниже). Так дом остаётся тем же во
  всех видах.
- Имена файлов: `<имя>.png` (спереди), `<имя>_side.png` (боком),
  `<имя>_back.png` (задом). Клади в `reference_map_level/textures/src/hd/houses_v6/`.
- Если вышло «чисто и мультяшно» — допиши в том же чате:
  `Too clean, too warm and toy-like. Match the attached outbuildings exactly:
  darker, colder, dirtier, heavier weathering, rougher irregular timber, muted
  grey-brown palette, no orange or reddish wood.`
- Если вышло высоко — допиши:
  `Make it LOWER and wider: the eaves of the front wall must be at most
  N hero heights above the ground` (N — из блока дома).
- Если у стен появились бочки, ящики, мешки:
  `Remove every loose object around the house: no barrels, crates, sacks,
  carts or firewood in front of or beside the walls. Only the building itself.`
- Если появилась земля или трава под домом:
  `Same house on a fully transparent background, no ground, no grass, no
  shadow on the ground.`

## Общий блок (вставлять в каждый запрос)

```
Single isolated building, game asset for a grim dark-fantasy action RPG.
MATCH THE ATTACHED OUTBUILDINGS SHEET EXACTLY in rendering style, materials,
level of detail, colour palette and lighting: it must look like part of the
same set. Use the attached game screenshot only for the camera angle and
scale.
Camera: high top-down 3/4 view, orthographic (no perspective distortion),
looking down at about 45-50 degrees, like the attached screenshot: the front
wall faces the viewer and the whole roof is clearly visible from above, the
roof takes about half of the image height. The bottom edge of the front wall
is a straight horizontal line.
Style: grim, realistic dark-fantasy concept art, painterly but NOT cartoon,
NOT stylized, NOT toy-like, NOT a mobile-game look. Rough, irregular,
hand-hewn timber, sagging lines, uneven shingles and turf, heavy weathering:
rain streaks, mud splashed on the lower logs, soot, moss in the shaded joints
of old roofs. Realistic proportions.
Palette: cold and desaturated — near-black and grey-brown weathered timber,
dark blue-grey fieldstone, grey shingles, olive-brown turf. Small accents
only: pale split wood where something was broken, dull rusted iron, a faded
red cloth. NO orange or reddish wood, NO warm golden light.
Light: overcast, dim, from the top-left; soft shadows under the eaves.
Setting: a Norse regional trading town, 11th-12th century. Log and plank
houses on low fieldstone footings, steep roofs of wooden shingles or turf,
small shuttered windows (no glass), heavy plank doors with iron hinges.
Ornament is modest: carved bargeboards and simple interlace only on richer
houses, no dragon heads unless the house text asks for them.
Story: a fanatical order sacked the town a few days ago. The house is solid
but freshly damaged: door hacked or kicked in, shutters torn off, soot above
a window, a few shingles or turf blocks torn off, an arrow stuck in a plank.
Not a ruin.
Output: transparent background (PNG with alpha), the whole building in frame
with a small margin, no ground plane, no grass around it, no cast shadow on
the ground, NO loose objects around the house (no barrels, crates, sacks,
carts, firewood piles, fences), no people, no animals, no corpses, no text.
Scale: the hero in the screenshot is 1 unit tall; doors are about 1.3 units
tall.
```

## Повороты (в том же чате, после вида спереди)

Боком (дверь смотрит влево, «вправо» — зеркало в движке):
```
Now draw the SAME house - same design, materials, colours and damage - but
rotated 90 degrees on the ground, so that its front wall with the main door
faces LEFT and the viewer looks at its side wall (the gable end if the roof
ridge runs left-right in the front view). The camera does not move: same high
top-down 3/4 orthographic view, the roof clearly visible from above, same
scale and lighting from the top-left. Transparent background, no ground, no
loose objects.
```

Задом (дверь на дальней стороне):
```
Now draw the SAME house - same design, materials, colours and damage - but
turned around 180 degrees, so that its back wall faces the viewer and the
main door is on the far side, not visible. The back wall has only a small
back door or one shuttered window. The camera does not move: same high
top-down 3/4 orthographic view, roof clearly visible from above, same scale
and lighting from the top-left. Transparent background, no ground, no loose
objects.
```

---

## Дома

Размеры — в ростах героя (герой ≈ 45 px в игре). «Карниз» — высота края крыши
над землёй у передней стены: это то, что решает, закрывает ли дом улицу.

| Имя | Что это | Ширина | Карниз | Повороты | Сколько в городе |
|---|---|---|---|---|---|
| `cottage` | одноэтажный сруб с дёрном | 5 | 1.8 | спереди, боком, задом | много |
| `gallery_house` | двухэтажный дом с галереей | 6 | 3.2 | спереди, боком, задом | много |
| `stone_house` | каменный низ, деревянный верх | 6 | 3.2 | спереди, боком, задом | средне |
| `merchant_gable` | узкий купеческий дом торцом к улице | 4.5 | 3.5 | спереди, боком, задом | средне |
| `longhouse` | длинный жилой дом с дёрном | 9 | 1.8 | спереди, боком, задом | мало |
| `craft_house` | дом ремесленника с навесом-мастерской | 6.5 | 2.2 | спереди, боком, задом | средне |
| `storehouse` | амбар на сваях | 3.5 | 2.4 | спереди, боком | мало |
| `burnt_gallery` | сгоревший двухэтажный дом | 6 | — | спереди, боком | мало |
| `burnt_cottage` | сгоревший сруб, рухнувшая крыша | 5 | — | спереди, боком | мало |

### cottage — одноэтажный сруб с дёрном
```
A small one-storey log cottage: thick round logs with notched corners on a
low fieldstone footing, a steep turf roof (olive-brown grass and earth over
birch bark) with a ragged edge, a short fieldstone chimney, one plank door
in the middle of the front wall and one small shuttered window beside it.
Damage: the door kicked in and hanging, a few turf blocks torn off near the
ridge, soot above the window.
Width about 5 hero heights; the eaves at the front about 1.8 hero heights
above the ground.
```

### gallery_house — двухэтажный дом с галереей
```
A two-storey Norse townhouse: log ground floor on a fieldstone footing,
vertical-plank upper floor, an open wooden gallery (svalgang) on simple posts
running along the upper floor, a steep wooden-shingle roof with modestly
carved bargeboards, a narrow outside stair up to the gallery at one end.
Damage: part of the gallery railing broken off and hanging, the ground-floor
door hacked, shingles missing in one patch, an arrow in a post.
Width about 6 hero heights; the eaves at the front about 3.2 hero heights
above the ground.
```

### stone_house — каменный низ, деревянный верх
```
A two-storey house of a wealthier family: the ground floor of rough dark
fieldstone with small deep window openings and an arched plank door, the
upper floor of dark timber slightly overhanging the stone, a steep shingle
roof, a stone chimney on one side. Simple interlace carving on the door
frame. Damage: the door forced open, soot streaks above the ground-floor
window, a shutter of the upper floor torn off.
Width about 6 hero heights; the eaves at the front about 3.2 hero heights
above the ground.
```

### merchant_gable — узкий купеческий дом торцом к улице
```
A narrow merchant's house standing with its gable end to the street, like the
old wharf houses of Bergen: vertical dark planks, two storeys plus a small
loft under a very steep shingle roof, a loft door high in the gable with a
wooden hoist beam above it, a wide plank door at the bottom for goods.
A single carved dragon head on the top of the gable (this house is rich).
Damage: the loft door torn off its hinges, the hoist rope cut and hanging,
the goods door smashed.
Width about 4.5 hero heights; the eaves at the front about 3.5 hero heights
above the ground.
```

### longhouse — длинный жилой дом с дёрном
```
A long, low Norse longhouse: plank and log walls on a fieldstone footing,
very slightly curved walls and ridge, a thick turf roof reaching low over the
walls, a smoke hole in the middle of the ridge, one entrance with a small
porch on the long side facing the viewer, two tiny shuttered windows.
Damage: the porch post broken and the porch roof sagging, a scorched,
caved-in patch in the turf roof.
Width about 9 hero heights; the eaves at the front about 1.8 hero heights
above the ground.
```

### craft_house — дом ремесленника с навесом
```
A one-storey craftsman's house with a loft: log walls on a fieldstone
footing, a steep shingle roof, and an open-fronted workshop lean-to under the
same roof on one end (a workbench, tool pegs on the wall, wood shavings on
its floor - all part of the building, inside the lean-to). A plank door and
a wide shuttered window in the house part.
Damage: the workbench overturned inside the lean-to, the window shutters
ripped off, soot on the logs.
Width about 6.5 hero heights; the eaves at the front about 2.2 hero heights
above the ground.
```

### storehouse — амбар на сваях
```
A small Norse storehouse (stabbur) raised on four short wooden posts with
flat stones on top of each post (against rats), a plank body slightly wider
at the upper floor, a steep shingle roof, a small door reached by a loose
wooden step-log. Damage: the door wrenched open, the step-log kicked aside
and lying on its side under the building.
Width about 3.5 hero heights; the eaves at the front about 2.4 hero heights
above the ground.
```

### burnt_gallery — сгоревший двухэтажный дом
```
The same kind of two-storey Norse townhouse with a gallery, burned out a few
days ago: the stone footing and the stone chimney still standing, the log
walls charred black and partly collapsed, the gallery fallen, the roof burned
away down to a few blackened rafters, grey ash and charred beams heaped
inside, a faint orange glow of embers deep in the rubble and a thin wisp of
smoke. Fresh destruction, NOT an old ruin: no plants, no moss.
Width about 6 hero heights.
```

### burnt_cottage — сгоревший сруб
```
A one-storey log cottage burned a few days ago: the turf roof collapsed into
the house, the front wall standing to half its height with charred log ends,
the door frame still upright, the fieldstone chimney intact, black ash and
broken charred logs filling the inside. No glow, cold and grey. Fresh
destruction, NOT an old ruin: no plants, no moss.
Width about 5 hero heights.
```

---

## Что я сделаю, когда пришлёшь

1. Порежу виды и соберу новый атлас домов. Масштаб — по росту двери, тон —
   под город.
2. Заменю дома в раскладке:
   - townhouse → `gallery_house` / `stone_house` / `cottage`;
   - merchant → `merchant_gable` / `stone_house`;
   - longhouse → `longhouse` / `craft_house`;
   - сгоревшие → `burnt_*`;
   - амбары поставлю в дворы.
3. Дома ниже, поэтому улицы станут видны лучше. Перепроверю коллизии, заборы
   и дворы, перепеку навмеш и проверю маршрут.
