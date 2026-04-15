# ASHENFALL — Главное меню (Godot 4)

## Структура файлов

```
ashenfall_menu/
├── scenes/
│   └── MainMenu.tscn          ← Основная сцена меню
├── scripts/
│   ├── MainMenu.gd             ← Контроллер меню (зум, интро, переходы)
│   ├── RainEffect.gd           ← Система частиц дождя
│   ├── EmberEffect.gd          ← Искры и угольки от костров
│   ├── BirdsEffect.gd          ← Процедурные птицы (без спрайтов)
│   └── MenuButton.gd           ← Кнопка с hover/click анимациями
├── assets/
│   └── shaders/
│       └── rain_overlay.gdshader  ← Альтернативный шейдерный дождь
└── theme/
    └── MenuTheme.tres          ← Тема кнопок меню
```

---

## Быстрый старт — пошагово

### 1. Скопируй файлы в свой проект Godot 4

Перенеси все папки в корень своего Godot проекта (`res://`).

### 2. Добавь фоновое изображение

В сцене `MainMenu.tscn` найди ноду `Background (TextureRect)`.
В инспекторе в поле `Texture` подключи свою картинку (твой арт воина).

Настройки TextureRect:
- `Expand Mode` → `Ignore Size`
- `Stretch Mode` → `Keep Aspect Covered`

### 3. Подключи пиксельный шрифт (опционально, но желательно)

Скачай пиксельный шрифт (например, `PixelOperator` или `Press Start 2P` — бесплатны).
Добавь `.ttf` в `res://assets/fonts/`.
В `MenuTheme.tres` добавь строку:
```
Button/fonts/font = ExtResource("your_font.ttf")
```

### 4. Настрой позиции источников огня

В сцене найди ноды `Embers1`, `Embers2`, `Embers3` (дочерние EffectsLayer).
Их `position` должна соответствовать кострам на твоём арте.
Смотри на арт и переставляй эмиттеры руками в 2D редакторе.

Можешь добавить больше эмиттеров — просто дублируй `Embers1` и перемести.

### 5. Альтернативный шейдерный дождь

Если хочешь более плотный дождь через шейдер вместо частиц:
1. Добавь `ColorRect` поверх Background (на весь экран)
2. В `Material` назначь `ShaderMaterial`
3. В `Shader` подключи `rain_overlay.gdshader`
4. Уменьши `modulate.a` до `0.3–0.45`

Параметры шейдера регулируй в инспекторе:
- `speed` — скорость падения
- `density` — количество капель
- `angle` — наклон (ветер)

---

## Подключение переходов сцен

В `MainMenu.gd` измени константы путей:
```gdscript
const SCENE_GAME := "res://scenes/Game.tscn"
const SCENE_SETTINGS := "res://scenes/Settings.tscn"
```

---

## Добавление фоновой музыки

1. Добавь `.ogg` файл в проект (`.ogg` рекомендован для фоновой музыки в Godot)
2. В сцене выбери ноду `AmbientMusic (AudioStreamPlayer)`
3. В инспекторе в поле `Stream` подключи свой файл
4. `Autoplay` уже включён

---

## Настройка анимации появления

В `MainMenu.gd` метод `_animate_intro()` — можешь изменить:
- `0.6` — задержка перед началом (секунды)
- `1.2` — время появления заголовка
- `1.5` — время появления кнопок

---

## Советы по производительности

- `GPUParticles2D` работает на GPU — почти бесплатно
- `BirdsEffect.gd` использует `_draw()` — лёгкий, без текстур
- Шейдер дождя тяжелее частиц на слабых GPU — выбери один из двух
- Для пиксельного стиля включи в `Project Settings → Rendering`:
  `Textures → Canvas Textures → Default Texture Filter` → `Nearest`
