# Хольмвик — промпты, партия 5: дворы

Зачем: дворы между домами были пустыми газонами — город выглядел недоделанным.
Первый проход уже сделан из того, что было (`tools/holmvik_yards.gd`):
- 57 участков;
- плетни с калитками вдоль улиц;
- поленницы, грядки, бельё, стога, загоны, бочки, мешки, телеги;
- утоптанная земля у хозяйства.

Чего не хватает, чтобы дворы стали по-настоящему живыми:
- **хозяйственных построек** (сейчас всё стоит под открытым небом);
- **разных заборов** (есть только один плетень);
- **мелочей быта**;
- **следов погрома** именно во дворах;
- **земли** — грядок, соломы, щепы, луж.

Правило проекта: всё, что персонаж (люди, животные), — пиксель-арт, поэтому
**никаких животных и людей** в этих листах — только постройки и вещи. Куры,
собаки, свиньи, если понадобятся, — отдельно, пиксельные.

## Как генерировать

- Один раздел — один **новый** чат. Приложи `holmvik_town_ref.png` и
  `holmvik_scale_ref.png` из `reference_map_level/textures/src/hd/refs/`
  (ракурс и масштаб) и **не** проси повторять их стиль: стиль задаёт текст.
- Скопируй **общий блок + блок раздела** (оба блока подряд) и отправь.
- Результаты клади в `reference_map_level/textures/src/hd/props_v5/`,
  имя файла — из заголовка раздела (`yard_buildings.png` и т. д.).
- Порядок предметов в листе важен (я режу лист по порядку слева направо,
  сверху вниз) — если какой-то предмет не вышел, перегенерируй лист, а не
  дорисовывай отдельно.
- Если вышло «мультяшно» — допиши в том же чате:
  `Too clean and toy-like. Make it grim, worn and realistic: irregular shapes,
  heavy weathering, mud, soot, darker and colder palette.`
- Если предметы слиплись — допиши:
  `Separate every item with wide empty transparent space, no overlaps.`

## Общий блок стиля (вставлять перед каждым разделом)

```
Game assets for a grim dark-fantasy action RPG, seen from a high top-down 3/4
camera, orthographic (no perspective distortion), looking down at about 45-50
degrees: the front faces the viewer and tops are clearly visible, exactly like
the attached reference screenshots (use them ONLY for camera angle and scale).
Art direction: grim, realistic dark-fantasy concept art, painterly but NOT
cartoon, NOT stylized, NOT toy-like, NOT a mobile-game look. Realistic
proportions, irregular and asymmetric, lived-in and worn: mud, moss on old
wood, rain stains, patched repairs.
Palette: cold and desaturated — dark weathered timber, grey thatch and
shingles, dark blue-grey stone, with LIGHT accents that keep the silhouette
readable at night: pale split wood, bleached cloth, straw, grey ash. Small
accents of rust and dried-blood red.
Light: overcast, dim, from the top-left; soft shadows.
Setting: the backyards of a Norse regional town (11th-12th century). Ordinary
families lived here until a few days ago, when a fanatical order (black
eclipse sun with a blood-red corona on its banners) sacked the town. The
yards are abandoned, not ruined to the ground.
Output: transparent background (PNG with alpha), each item fully separated by
wide empty transparent space, no ground plane, no grass around the items, NO
people, NO animals, NO corpses, no text, nothing modern. Scale: the hero in
the reference screenshot is 1 unit tall.
```

---

## 1. yard_buildings — хозяйственные постройки

Главное, чего не хватает: дворы без построек выглядят как газон с вещами.
Ставятся у задней кромки двора, к стене дома или забору.

```
A sprite sheet of 8 separate small yard outbuildings, each standing on its
own, the front facing the viewer:
1. a chicken coop: small raised timber hut on short legs with a little
   ramp, a shingle roof with moss, a tiny door hanging open (about 1.2 hero
   heights tall, 1.5 wide);
2. an outhouse: narrow plank privy with a slanted roof and a crescent hole
   in the door (about 1.6 hero heights tall);
3. an open tool shed: three walls of planks and a sloping roof, rakes,
   scythe, axes and a ladder leaning inside (about 1.5 tall, 2 wide);
4. a small smokehouse: squat stone-and-timber hut with a short chimney,
   soot-blackened around the roof (about 1.5 tall, 1.5 wide);
5. a dog kennel: small plank kennel with a shingle roof, a broken chain and
   an empty wooden bowl in front (about 0.8 tall);
6. a row of 3 straw beehives (skeps) on a low plank bench under a small
   roof (about 1 tall, 2 wide);
7. a root-cellar entrance: a low stone frame with a slanted double plank door
   in the ground, one door torn open (about 0.7 tall, 1.5 wide);
8. a lean-to shelter against nothing (one sloping roof on 4 posts) with a
   two-wheeled hand cart and stacked firewood under it (about 1.6 tall,
   2.5 wide).
```

---

## 2. yard_fences — заборы и калитки

Сейчас во всём городе один вид плетня. Нужны разные заборы, чтобы дворы
отличались, и **куски, которые стыкуются** в длинную линию.

```
A sprite sheet of 10 separate fence pieces for yards. Every straight segment
has clean vertical cut ends at the posts so segments can be placed end to end
into a long seamless line. Front-facing segments run left-right across the
image; SIDE segments run away from the viewer (we see them from above along
their length, so they are tall and narrow in the image).
1. picket fence segment, front-facing: pointed vertical planks on two rails,
   weathered grey, about 0.9 hero heights tall, 3 hero heights long;
2. the same picket fence, front-facing, damaged: two planks missing, one
   kicked in and leaning;
3. picket fence SIDE segment running away from the viewer, 3 hero heights
   long;
4. a picket-fence gate between two thicker posts, the gate hanging open on
   one hinge;
5. a wattle (woven branches) gate between two posts, closed, tied with rope;
6. a low dry-stone wall segment, front-facing: flat field stones without
   mortar, moss on top, about 0.6 hero heights tall, 3 hero heights long;
7. the same dry-stone wall, front-facing, partly collapsed in the middle with
   stones spilled in front;
8. dry-stone wall SIDE segment running away from the viewer, 3 hero heights
   long;
9. a dry-stone wall corner piece (an L seen from the 3/4 camera);
10. a split-rail fence segment (two long rough rails on X-crossed posts),
   front-facing, about 0.8 tall, 3 long.
```

---

## 3. yard_life — быт двора

Мелочи, по которым видно, что здесь жили люди. Ставятся у стен домов, у
дверей, под навесами.

```
A sprite sheet of 14 separate small household items found in a Norse yard:
1. a rough plank bench;
2. a heavy plank table with two stools;
3. a wooden washtub with a washboard leaning in it;
4. a spinning wheel;
5. a grindstone on a wooden frame with a crank;
6. an anvil on a tree stump with tongs and a hammer;
7. a stack of 3 woven baskets, one with turnips;
8. a group of clay pots and jars of different sizes;
9. a two-wheeled hand cart, empty, tilted forward on its shafts;
10. a butter churn and a milk pail;
11. upright sheaves of grain leaning against each other (3 sheaves);
12. a drying rack with bundles of herbs and onions hanging from it;
13. a small round firewood stack (split logs stacked in a circle) with a
    pointed bark cap;
14. a cauldron on an iron tripod over a cold, ashy fire pit with stones.
```

---

## 4. yard_raid — следы погрома во дворах

Город взят несколько дней назад: дворы обыскали и бросили. Нужен беспорядок,
который читается сверху, но **без тел и крови в каждом кадре** — кровь уже
есть отдельно.

```
A sprite sheet of 10 separate items showing yards that were searched and
looted a few days ago:
1. an overturned bench with smashed clay pots and a spilled basket of
   turnips around it;
2. torn-open grain sacks with grain spilled on the ground in a fan;
3. a kicked-over firewood stack, logs scattered;
4. a smashed wooden chest, lid torn off, clothes and small belongings
   strewn around it;
5. a broken spinning wheel lying on its side;
6. a chicken coop with its roof torn off and the door hanging, feathers
   around (no birds);
7. a fence section knocked flat to the ground, trampled into mud;
8. a burnt patch of fence: 2-3 charred posts with stumps of planks, ash
   below;
9. bed linen and clothes torn off a laundry line and trampled in the mud,
   the line still hanging from one post;
10. a toppled cart with a broken wheel and its load of hay spilled out.
```

---

## 5. yard_ground — земля двора (плоские декали)

Плоские картинки, лежащие на земле: шейдер земли умеет только траву и
утоптанную землю, а двору нужны грядки, солома, щепа, лужи. Ракурс тот же
(3/4 сверху), но предмет **плоский** — без высоты, мягкий край, уходящий в
прозрачность (ляжет на любую траву без рамки).

```
A sprite sheet of 9 separate FLAT ground decals, lying on the ground, seen
from the same high 3/4 camera. They have no height, soft irregular edges
that fade into transparency so they blend onto any grass, and no grass of
their own:
1. a vegetable garden plot: 4 rows of dark tilled earth with cabbages and
   onion tops, edged with a low wattle border, about 3 x 2 hero heights;
2. a smaller plot: 2 rows with turnip leaves, half of it trampled;
3. a herb patch, loose and overgrown;
4. scattered straw and hay on muddy ground;
5. wood chips and bark around a chopping spot;
6. a muddy puddle with ruts and footprints, reflecting a grey sky;
7. a patch of trampled mud with boot and hoof prints;
8. a dark ash pit, the remains of a small burnt fire with charred sticks;
9. a pile of dung and old straw by a pen (subtle, not cartoonish).
```

---

## Что будет после генерации

Положишь листы в `textures/src/hd/props_v5/`, а я:
1. порежу их в атлас дворов;
2. добавлю в `tools/holmvik_yards.gd` новые хозяйства:
   - курятник с соломой и грядкой;
   - мастерская — точило, наковальня, навес;
   - пасека;
   - двор с погребом;
3. сменю ограду: у каждого двора свой забор — плетень, штакетник или
   каменная кладка, с калиткой;
4. добавлю на землю грядки, солому и лужи;
5. часть дворов сделаю разорёнными.
