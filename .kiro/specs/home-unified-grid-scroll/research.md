# Research & Design Decisions — home-unified-grid-scroll

## Summary

- **Feature**: `home-unified-grid-scroll`
- **Discovery Scope**: Extension (existing system) — рефактор cinematic-главного экрана, переиспользует upstream спеки.
- **Key Findings**:
  - Существующий `cinematic_home_screen.dart` использует `Stack(Positioned(hero, top:0, h:620) + Positioned(ListView rails, top:620))`. Hero и rails имеют независимые scroll-вьюеры.
  - `HeroTileMorph` (363 строки) реализует geometry+opacity morph через 300 ms `AnimationController` — компромисс, который пользователь явно отверг.
  - Горизонтальный `Pinned-Slot Invariant` уже работает в `CinemaRow._scrollFocusedTileToLeadingEdge` (`targetOffset = (index - pinnedSlotIdx) * cardStride`, clamp `[0, maxScrollExtent]`); формально протестирован 3 кейсами в `cinema_row_pinned_slot_test.dart`.
  - `FirstSlotConfig` (slot-0 override в `CinemaRow`) добавлен спекой `hero-collapse-tile-morph` и теряет смысл с удалением `HeroTileMorph`.
  - `cardHeightDp = 720` (cinema row), hero height сейчас 620; rowStride математика не-uniform.
  - `flutter-tv-perf.md` запрещает `AnimatedContainer.height` — текущий morph его не использует (Stack-positioned), но vertical scroll должен полагаться исключительно на анимацию `ScrollPosition.pixels`.

## Research Log

### Horizontal Pinned-Slot Invariant — образец для вертикального аналога

- **Context**: Brief спеки прямо указывает что «применить тот же контракт что в `home-grid-stability-pass` (`pinnedSlotIdx=1`), но на вертикальной оси».
- **Sources Consulted**:
  - `megav_iptv/lib/features/home/widgets/cinema_row.dart:108–152` — dartdoc формального контракта.
  - `megav_iptv/lib/features/home/widgets/cinema_row.dart:286–307` — `_scrollFocusedTileToLeadingEdge`.
  - `megav_iptv/test/features/home/widgets/cinema_row_pinned_slot_test.dart` — три тестовых клаузы.
- **Findings**:
  - Алгоритм: `targetOffset = (focusedIdx - pinnedSlotIdx) * stride; offset.clamp(0, maxScrollExtent)`.
  - Stride для горизонтальной оси = `cardW + gap` (uniform).
  - Анимация: 250 ms `Curves.fastOutSlowIn` (Leanback `lb_browse_rows_anim_duration`).
- **Implications**:
  - Вертикальный аналог использует ту же clamping математику, но stride = высоты предыдущих рядов (non-uniform: hero ≠ row).
  - Анимация для вертикальной оси по brief = 300 ms `easeInOutCubic` (отличается от горизонтальной — намеренно по UX-решению brief).

### Hero height vs cardHeight — non-uniform stride

- **Context**: Brief говорит «hero — это row-0, height ≈ 600 dp», а cinema rows `cardHeightDp = 720`. Нужно решить как считать vertical offset.
- **Sources Consulted**:
  - `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart:376` — `const expandedH = 620.0;`
  - `megav_iptv/lib/features/home/widgets/_grid_tokens.dart:126` — `static const double cardHeightDp = 720;`
- **Findings**:
  - Hero фактически 620 dp в текущей реализации; brief предлагает round до 600 для чистоты.
  - Поскольку всего 2 типа row (hero + cinema-row), prefix sum считается в O(1): `if (focusedIdx == 1) return 0; if (focusedIdx == 2) return heroH; if (focusedIdx >= 3) return heroH + (focusedIdx - 2) * cardH;`.
- **Implications**:
  - Не нужно динамически измерять высоту рядов через `RenderBox.localToGlobal` — формула достаточна.
  - При добавлении новых row types в будущем (e.g. polish или promo banners) — потребуется обобщение через массив `rowHeights[]` (см. Revalidation Triggers в design.md).

### TV-perf compliance в новом scroller

- **Context**: `flutter-tv-perf.md` строго запрещает несколько операций; нужно подтвердить что новая модель им не противоречит.
- **Sources Consulted**:
  - `megav_iptv/.kiro/steering/flutter-tv-perf.md`.
- **Findings**:
  - Анимация `ScrollPosition.pixels` через `ScrollController.animateTo` — GPU-friendly (Impeller обрабатывает scroll как paint offset).
  - `cacheExtent: 1500` + `addRepaintBoundaries: true` уже стандарт в проекте для ListView.
  - Нет необходимости в `BackdropFilter` / `ShaderMask` / `AnimatedContainer` в новом scroller-е.
- **Implications**:
  - Дизайн соответствует pre-PR чек-листу из `flutter-tv-perf.md` без оговорок.

### macOS desktop parity через `WidgetOrderTraversalPolicy`

- **Context**: Req 8.x требует одинакового поведения на macOS и TV.
- **Sources Consulted**:
  - `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart:404–406` — `FocusTraversalGroup(policy: WidgetOrderTraversalPolicy())`.
- **Findings**:
  - `WidgetOrderTraversalPolicy` уже используется в проекте именно для parity macOS ↔ TV (комментарий в коде это явно фиксирует).
  - D-pad ↑/↓/←/→ на TV mapятся на `LogicalKeyboardKey.arrowUp/Down/Left/Right` — тот же что и клавиатура на macOS.
- **Implications**:
  - Никакой platform-specific логики не требуется; vertical scroller использует тот же policy.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| **Single ListView с hero как row-0** (выбранный) | `ListView.builder(itemCount: 1+N+1)` где idx=0 — hero, idx=1..N — rails, idx=N+1 — footer | Один scroll-controller, симметрия с горизонтальным invariant, минимальная code surface | Non-uniform stride требует prefix-sum математики | Brief прямо предлагает этот вариант |
| Sliver-based (`CustomScrollView`) | `SliverToBoxAdapter(hero) + SliverList(rails)` | Гибкость для будущих sticky-headers / pinned elements | Сложнее clamping математика (нужно SliverGeometry), больше boilerplate | Overengineering для текущего scope |
| Stack + animated `top` | Анимировать `top` hero через `AnimatedPositioned` | Знакомый паттерн | Прямо запрещён в `cinematic_home_screen.dart:504–506` комментарий — ломает ScrollController attachment | Отвергнут |

## Design Decisions

### Decision: Hero как row-0 единого ListView, не SliverToBoxAdapter

- **Context**: Нужно решить структуру родительского scroll-вьюера.
- **Alternatives Considered**:
  1. `ListView.builder(itemCount: 1+N+1, itemBuilder: …)` где idx=0 — `HeroAsRow`, idx=1..N — `CategoryRowWrapper`, idx=N+1 — footer.
  2. `CustomScrollView(slivers: [SliverToBoxAdapter(hero), SliverList(rails), SliverToBoxAdapter(footer)])`.
- **Selected Approach**: ListView.builder.
- **Rationale**: Симметрия с горизонтальным `ListView.builder` в `CinemaRow`. Один `ScrollController` с прямым доступом к `position.pixels` / `maxScrollExtent` для clamping. Меньше boilerplate. Достаточно для текущего scope.
- **Trade-offs**: Если в будущем появится sticky-header или pinned promo-блок поверх scroll — потребуется миграция на Sliver. Запись в Revalidation Triggers.
- **Follow-up**: Не требуется.

### Decision: Vertical scroll animation 300 ms easeInOutCubic (отличается от horizontal 250 ms fastOutSlowIn)

- **Context**: Brief явно указывает «Анимации — `Curves.easeInOutCubic`, ≤ 300 ms».
- **Alternatives Considered**:
  1. Использовать те же 250 ms `fastOutSlowIn` что и для горизонтальной оси.
  2. Использовать brief-указанные 300 ms `easeInOutCubic`.
- **Selected Approach**: 300 ms `easeInOutCubic` per brief.
- **Rationale**: Brief — единственный source of truth для requirements. Вертикальный скролл «тяжелее» визуально (больше пиксельной площади перерисовывается), чуть более медленная кривая лучше соответствует ожиданию плавности. Leanback не имеет специального токена для cross-row vertical scroll.
- **Trade-offs**: Визуальная асимметрия между ←/→ (250 ms) и ↑/↓ (300 ms). Приемлемо.
- **Follow-up**: Если на rtd2851a 300 ms даёт jank при frame budget — снизить до 250 ms (изменение константы в `GridTokens`).

### Decision: Удалить HeroTileMorph + FirstSlotConfig в той же спеке

- **Context**: Brief требует удалить `hero_tile_morph.dart`. `FirstSlotConfig` существует только для morph-механизма.
- **Alternatives Considered**:
  1. Удалить в этой же спеке (cohesive change).
  2. Оставить как dead code, удалить отдельной cleanup-спекой.
- **Selected Approach**: Удалить в этой спеке.
- **Rationale**: Атомарность: один commit = «hero как row-0 вместо collapse». Pre-commit hook поощряет сокращение dead code.
- **Trade-offs**: Spec touch surface растёт (трогаем `cinema_row.dart`); но изменение там минимальное — убрать optional param и одну ветку в itemBuilder.
- **Follow-up**: Спека `hero-collapse-tile-morph` помечается как obsolete (в README/note), но её директория сохраняется.

## Risks & Mitigations

- **Risk 1**: Non-uniform row heights (hero ≠ row) могут запутать clamping математику. — **Mitigation**: только 2 типа, формула O(1); добавить assertion в debug build.
- **Risk 2**: Удаление `FirstSlotConfig` из `CinemaRow` может сломать тесты или другой код. — **Mitigation**: проверить grep по `FirstSlotConfig` и `firstSlot` перед коммитом; обязательная проверка `flutter analyze` после edit.
- **Risk 3**: На rtd2851a 300 ms vertical scroll может «тянуть» при одновременном hover-preview start. — **Mitigation**: hover-preview debounce 600 ms (`_hoverSettleDelay`) гарантирует что start не пересечётся с обычным sweep; на live-смоке проверить отдельно.
- **Risk 4**: Тест Vertical Pinned-Slot Invariant потребует измерения screen-space Y по похожему API `localToGlobal` — стиль и harness уже отработаны на `cinema_row_pinned_slot_test.dart`. — **Mitigation**: использовать его как образец 1:1.

## References

- Brief: `.kiro/specs/home-unified-grid-scroll/brief.md`
- TV-perf rules: `.kiro/steering/flutter-tv-perf.md`
- Horizontal invariant contract: `megav_iptv/lib/features/home/widgets/cinema_row.dart` (dartdoc + impl)
- Horizontal invariant test: `megav_iptv/test/features/home/widgets/cinema_row_pinned_slot_test.dart`
- Upstream спеки: `home-grid-optimization`, `home-grid-stability-pass`, `home-cinematic-redesign`, `hero-collapse-tile-morph` (obsoleted by this spec)
