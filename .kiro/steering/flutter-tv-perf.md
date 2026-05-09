# Flutter TV Performance — правила

Свод проверенных перф-уроков из трёх закрытых спеков (`home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine`). Все измерения сделаны на референсном TV-боксе **Realtek `rtd2851a`** (32-bit ARM, Mali-class GPU, Android TV) через **VM Service `getVMTimeline`** в `--profile` сборке.

Применяй эти правила **до** того как писать новый UI или добавлять «красоту» — не после, когда всё уже тормозит.

---

## TL;DR — три правила

1. **Никаких `ShaderMask` / `BackdropFilter` / `BoxShadow.blurRadius > 12`** на TV-боксах класса Mali. Любая из этих операций = saveLayer + shader compile = 26+ мс/кадр. Замеряли: ShaderMask на ListView дал **avg 46.6 мс/кадр (21 fps)** в скролле; замена на `Stack + Positioned + DecoratedBox(LinearGradient)` дала **avg 10.2 мс (98 fps)** — улучшение **78%**.

2. **Не ребилди дерево от тиков стримов.** `StreamBuilder<X>` внутри большого build — **антипаттерн**. Каждый тик ребилдит весь parent. Изоляция: вынести в отдельный `ConsumerWidget` или `StatefulWidget` под `RepaintBoundary` + `const` ctor у parent'а.

3. **Не заставляй активный фокус двигать соседей.** Если активная плитка раздувается в 2× ширины — соседние двигаются → relayout всего ListView каждый focus-change. Используй `Transform.scale(1.05)` вместо `AnimatedContainer.width` — это GPU-операция, без relayout.

---

## Что вредно (avoid)

### ShaderMask + BlendMode.dstOut

**Цена**: 3-6 мс/кадр saveLayer + 260 мс one-shot shader compile при первом скролле.

```dart
// ❌ ПЛОХО на TV-боксе:
ShaderMask(
  shaderCallback: (rect) => LinearGradient(...).createShader(rect),
  blendMode: BlendMode.dstOut,
  child: ListView(...),
)

// ✅ Альтернатива:
Stack(children: [
  ListView(...),
  Positioned(
    right: 0, top: 0, bottom: 0,
    width: rowWidth * 0.05,
    child: const IgnorePointer(
      child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [Color(0x00000000), Color(0xFF08080F)], // → bg
        ),
      )),
    ),
  ),
])
```

Работает только если фон под маской **известный/uniform**. Над hero-видео или картинкой fade-overlay не сработает — там **нужна** реальная transparency, и ShaderMask придётся принять как plata. Но на главном экране, sidebar-меню, диалогах — gradient overlay всегда дешевле.

### BoxShadow.blurRadius > 12

**Цена**: gaussian blur каждый кадр пока shadow видна.

```dart
// ❌ ПЛОХО (был в cinema_card.dart, дал лаги):
BoxShadow(
  color: AppColors.primary.withValues(alpha: 0.30),
  blurRadius: 50, spreadRadius: -12,
)

// ✅ Используй яркую рамку вместо blur:
Border.all(color: AppColors.primary, width: 3.0)
// Или совсем лёгкую тень:
BoxShadow(blurRadius: 12, ...)
```

Это спорный зрительный компромисс — у Netflix вообще нет blur-теней у фокусированных карточек, только border + scale. Это **не баг дизайна Material**, это **физическое ограничение** TV-GPU.

### Опции вокруг видео-Texture

Каждый дополнительный full-screen layer над видео-Texture стоит **~1-3 мс** на TV-Mali GPU.

- **3 stacked full-screen `LinearGradient`** поверх Hero-видео = 3-5 мс. Сводить к **одному**.
- `Opacity(opacity: < 1)` поверх Texture = saveLayer + дополнительный composite. После завершения tween → drop the wrapper.
- `BackdropFilter` поверх видео — **категорически нет** на TV. Дороже ShaderMask.

### `AnimatedContainer.width` при focus

Вызывает relayout соседей. Для focus-эффектов используй:

```dart
// ❌ ПЛОХО:
AnimatedContainer(
  width: isFocused ? widthFull : widthNarrow, // relayout!
  ...
)

// ✅ ХОРОШО:
AnimatedScale(
  scale: isFocused ? 1.08 : 1.0, // GPU-only
  alignment: Alignment.center,
  ...
)
```

### `if`-conditional `AnimatedOpacity` без unmount-fade

```dart
// ❌ ПЛОХО — резко выключается, fade-out не успевает:
if (showOverlay) AnimatedOpacity(opacity: 1.0, duration: ...)

// ✅ Вариант 1: Visibility + AnimatedOpacity + delay-flag для fade-out hold
Visibility(
  visible: isFocused || _focusJustLost, // _focusJustLost = bool, true on focus loss + Timer(overlayFade)
  maintainState: false,
  child: AnimatedOpacity(opacity: isFocused ? 1.0 : 0.0, duration: 150ms, child: ...)
)

// ✅ Вариант 2: AnimatedSwitcher
AnimatedSwitcher(
  duration: 150ms,
  child: showOverlay ? OverlayContent(key: ValueKey('on')) : SizedBox.shrink(key: ValueKey('off')),
)
```

### Постоянная подписка на стримы в большом build

```dart
// ❌ ПЛОХО — каждый тик ребилдит ВСЕ children Stack:
Widget build(BuildContext context) {
  return Scaffold(body: Stack(children: [
    VideoWidget(),
    StreamBuilder<PlayerState>(stream: ..., builder: ...),  // ← виновник
    OverlayLayer(),
  ]));
}

// ✅ ХОРОШО — изолирован через const + RepaintBoundary:
Widget build(BuildContext context) {
  return Scaffold(body: Stack(children: [
    VideoWidget(),
    const _LoadingErrorIndicator(),  // ← const ctor → parent не ребилдится при тике
    OverlayLayer(),
  ]));
}

class _LoadingErrorIndicator extends ConsumerWidget {
  const _LoadingErrorIndicator();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: StreamBuilder<PlayerState>(
        stream: ref.watch(playerManagerProvider).stateStream,
        builder: (...) { ... },
      ),
    );
  }
}
```

Эффект: BUILD-events в idle снизились **с ~50/30 сек до ≤5/30 сек** на rtd2851a.

---

## Что полезно (do)

### Адаптивная сетка из чистых констант

`flutter_screenutil` хорош, но pure-токены отдельно от runtime-context лучше:

```dart
// ✅ В _grid_tokens.dart (pure leaf, only flutter/animation.dart):
class GridTokens {
  static const Duration focusAnimation = Duration(milliseconds: 150);
  static const Curve scrollCurve = Curves.fastOutSlowIn;
  static const double focusedScale = 1.08;
  static const double gapDp = 16;             // raw, NO .w here
  // ...
}

int pickColumns(double screenW) {
  if (screenW < 1280) return 3;
  if (screenW < 2560) return 4;
  return 5;
}
```

Потребители умножают на `.w` / `.h` на use-site. Юнит-тесты проходят без screenutil.

### Leanback-ориентированные тайминги

Из ресурсов AndroidX Leanback (база Netflix Android TV) — эталоны для TV-UX:

| Назначение | Длительность |
|---|---|
| Card focus animation | **150 ms** (`lb_card_activated_animation_duration`) |
| Selection delay (debounce) | **400 ms** (`lb_card_selected_animation_delay`) — игнорируем focus-change короче этого |
| Row scroll | **250 ms** (`lb_browse_rows_anim_duration`) |
| Scroll easing | `decelerateInterpolator factor=2.0` ≈ Flutter `Curves.fastOutSlowIn` |
| OSD show timeout | **3000 ms** (`lb_playback_controls_show_time_ms`) |
| OSD fade-in | **250 ms** (`lb_playback_controls_fade_in_ms`) |
| OSD fade-out | **325 ms** (`lb_playback_controls_fade_out_ms`) |

Если делаешь TV-UX — используй эти числа, не выдумывай свои.

### Debounce hover-эффектов на 400 мс

При быстром скролле пультом фокус пролетает плитки за 50-100 мс. Тяжёлые операции (раскрытие full-overlay, обновление hero-баннера, запуск preview-плеера) запускать **не сразу** на focus-change:

```dart
Timer? _focusStableTimer;

void _onFocus(int index) {
  setState(() => _focusedIndex = index);  // мгновенный scale
  _focusStableTimer?.cancel();
  _focusStableTimer = Timer(const Duration(milliseconds: 400), () {
    if (!mounted || _focusedIndex != index) return;
    widget.onItemFocus?.call(items[index]);  // тяжёлое действие
  });
}
```

`null`-clear делать **синхронно**, без debounce — иначе UI будет «застревать» когда фокус ушёл.

### Атомарный `_transition` для state-машины

Если у тебя есть screen с несколькими overlay-режимами (плеер, sidebar, modal-flow), не делай 5 boolean-флагов + 3 таймера. Используй sealed-класс + один таймер expiry + одну точку мутации:

```dart
sealed class UiState {}
final class HiddenState extends UiState { const HiddenState(); }
final class ShownState extends UiState {
  final DateTime hideAt;
  const ShownState({required this.hideAt});
}

UiState _state = const HiddenState();
Timer? _expiryTimer;

void _transition(UiState newState) {
  _expiryTimer?.cancel();           // ← cancel BEFORE setState
  _expiryTimer = null;
  setState(() => _state = newState);
  final expiryMs = switch (newState) {
    HiddenState() => null,
    ShownState s => s.hideAt.difference(DateTime.now()).inMilliseconds,
  };
  if (expiryMs != null && expiryMs > 0) {
    _expiryTimer = Timer(Duration(milliseconds: expiryMs), _onExpiry);
  }
}
```

Sealed-класс даёт **compile-time exhaustiveness** в `switch` — невалидное состояние не выразить. Один таймер исключает race-условия.

### Re-entry guard для async actions

```dart
bool _inFlight = false;

Future<void> _doAsyncAction() async {
  if (_inFlight) return;
  _inFlight = true;
  try {
    final result = await api.fetch(...);
    _transition(NewState(result));
  } finally {
    _inFlight = false;
  }
}
```

Иначе быстрые повторные нажатия пультом стартуют параллельные fetch'и, и race-условия гарантированы.

### `cacheExtent: 1500.w` + `addAutomaticKeepAlives: true` + `addRepaintBoundaries: true`

Стандартные настройки для горизонтального ListView сетки на TV. Без этого скролл лагает на каждом 5-м пункте.

```dart
ListView.builder(
  scrollDirection: Axis.horizontal,
  cacheExtent: 1500,                        // запас "под капотом"
  addAutomaticKeepAlives: true,             // не убивать state при скролле
  addRepaintBoundaries: true,               // изоляция перерисовок
  clipBehavior: Clip.none,                  // не клипать scale-эффекты соседей
  itemBuilder: ...
)
```

### Visibility wrap для скрываемого тяжёлого UI

Если у тебя в карточке/панели есть «тяжёлая» часть (5+ декорированных Container'ов с бейджами, прогресс-бар, текст) которая видна только в активном состоянии:

```dart
// ❌ ПЛОХО — heavy subtree билдится для каждой неактивной плитки:
Stack(children: [
  poster,
  AnimatedOpacity(opacity: isFocused ? 1 : 0, child: HeavyOverlay()),
])

// ✅ ХОРОШО — heavy subtree вообще не строится для неактивных:
Stack(children: [
  poster,
  Visibility(
    visible: isFocused || _focusJustLost,  // hold flag для fade-out
    maintainState: false, maintainSize: false, maintainAnimation: false,
    child: AnimatedOpacity(opacity: isFocused ? 1 : 0, child: HeavyOverlay()),
  ),
])
```

`_focusJustLost` — это bool-flag, ставится в `true` при потере фокуса, через `GridTokens.overlayFade + 16ms` Timer возвращается в `false`. Это даёт fade-out успеть до удаления subtree из дерева.

---

## Как замерять — VM Service не DevTools

DevTools UI **не нужен**. VM Service отвечает на простой `curl`:

```bash
# Получить URL: в терминале flutter run нажать `v`, скопировать URL вида:
# http://127.0.0.1:NNNNN/TOKEN=/

VMURL="http://127.0.0.1:NNNNN/TOKEN="

# Включить streams (Embedder = GPU events):
curl -sf "$VMURL/getVMTimelineFlags"

# Очистить буфер:
curl -sf "$VMURL/clearVMTimeline"

# Подождать N сек (idle / scroll / scenario), снять trace:
sleep 5
curl -sf "$VMURL/getVMTimeline" -o /tmp/trace.json
```

Парсинг — Python с pairing B/E events по `tid + name`, считаешь `dur = E.ts - B.ts` для `GPURasterizer::Draw`. См. примеры в `.kiro/specs/home-grid-visual-polish/snapshots/scroll_trace_after_fix.json` (4.9 МБ).

**Главные метрики**:
- avg `GPURasterizer::Draw` — целевое ≤ **16.7 мс** (60 fps).
- p95 — ≤ 25 мс приемлемо.
- max — спорадические пики до 30 мс это GC, не код. Регулярные пики 50+ — bug.
- `BUILD` events count за 30 сек idle — целевое ≤ 5.

**Важный нюанс**: первые 2-3 секунды после launch — это **shader compilation cache miss**. Цифры в это время меньше реальной production картины. Прогревай 5-8 сек перед измерением.

---

## Чек-лист перед PR на TV-фичу

- [ ] Никаких `ShaderMask`, `BackdropFilter`, `ImageFilter.blur` в hot-path (за пределами одноразовых boot-overlay).
- [ ] `BoxShadow.blurRadius` ≤ 12 везде где shadow перерисовывается каждый кадр.
- [ ] Активный фокус — `Transform.scale`, не `AnimatedContainer.width`.
- [ ] Стримы изолированы в отдельные виджеты с `RepaintBoundary` + `const` ctor у parent'а.
- [ ] Тайминги — Leanback (150/250/400 мс).
- [ ] Curves — `fastOutSlowIn` для скролла, `easeOutCubic` для focus.
- [ ] Heavy overlays для не-активного состояния обёрнуты в `Visibility(visible: false)` (с hold-флагом для fade-out).
- [ ] ListView с `cacheExtent: 1500`, `addAutomaticKeepAlives`, `addRepaintBoundaries`.
- [ ] Async actions защищены `_inFlight` guard.
- [ ] Sealed `_uiState` + один Timer — для любого экрана с 3+ режимами видимости.
- [ ] Замерено через `getVMTimeline` на rtd2851a, avg ≤ 16.7 мс при скролле / в idle.

---

## Источники чисел

- `home-grid-optimization` спек (commit `e78e84c`): убрали blur=50, expanded-режим, добавили pickColumns.
- `home-grid-visual-polish` спек (commit `7cefae0`): добавили fade-edge, Visibility wrap, нашли регрессию ShaderMask, заменили на DecoratedBox-overlay (commit `8851c07`). **Главные числа этого документа из этого спека.**
- `player-overlay-state-machine` (in-progress): sealed-state-machine + RepaintBoundary вокруг StreamBuilder.

VM Service trace artifacts:
- `.kiro/specs/home-grid-visual-polish/snapshots/scroll_trace_with_shadermask.json` (до — avg 46.6 мс).
- `.kiro/specs/home-grid-visual-polish/snapshots/scroll_trace_after_fix.json` (после — avg 10.2 мс).
- `.kiro/specs/player-overlay-state-machine/snapshots/baseline_player_open_trace.json` (плеер idle — avg 12.2 мс).

Если что-то из правил окажется неверным на новой версии Flutter / новом железе — дополни / поправь этот файл с указанием SHA коммита, который опровергает.
