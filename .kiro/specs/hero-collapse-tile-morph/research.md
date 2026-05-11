# Research — hero-collapse-tile-morph

## Цель research-фазы

Зафиксировать **discovery findings**, **рассмотренные альтернативы** и
**обоснование выбранных решений** перед написанием `design.md`. Документ
читает design-агент и будущий impl-агент: тут не повторяется brief, а
доказательно обосновывается каждый ключевой выбор.

Все ключевые наблюдения сделаны через прямое чтение исходников
`cinematic_home_screen.dart` (562 строки), `cinema_row.dart` (524 строки),
`_grid_tokens.dart` (92 строки) и upstream-спека `home-grid-stability-pass`
(design.md, requirements.md, tasks.md).

## Discovery: текущее устройство hero collapse

### Hero как отдельный Positioned

`CinematicHomeScreen.build` строит `Stack(children: [hero, rails, boot])`
где hero — `Positioned(top: 0, left: 0, right: 0, height: 620)`. Внутри
hero — `Focus(skipTraversal: true, onFocusChange: ...)` слушатель,
который выставляет `_heroFocused` в `setState`. Дальше идёт
`AnimatedCrossFade(duration: 220ms, crossFadeState: _heroFocused ?
showFirst : showSecond)`:

- `firstChild` = `CinematicHeroBlock(backdropImage, heroItem,
  heroWatchFocusNode, ...)` — полный hero с backdrop + Watch button.
- `secondChild` = `Align(child: CinematicCompactHero(item))` —
  компактный hero ~110 px или `SizedBox(height: collapsedH)` если
  heroItem null.

Rails живут в `Positioned(top: 620, left: 0, right: 0, bottom: 0)` →
`ListView.builder` рендерит `CategoryRowWrapper(...)`.

**Ключевое наблюдение**: rails позиционированы через **фиксированный**
`top: 620` (не `AnimatedPositioned`). Комментарий в коде явно говорит:
«Hero collapse animates only via crossfade — NOT via AnimatedPositioned
top change, because animating `top` reparents children every frame and
breaks ScrollController attachment.» Это исторический урок —
ScrollController-attached-twice бага была реальной.

### Состояние, которое нельзя потерять при рефакторе

1. `_focusNode` (`cinematicHomeShell`) — корневой Focus.
2. `_heroWatchFocusNode` (`cinematicHeroWatch`) — focus на Watch button,
   через `addListener(_onHeroWatchFocusChanged)` управляет `_heroFocused`.
3. `_heroFocused: bool` — единственный driver crossfade.
4. `_carouselTimer` — `Timer.periodic(8s)` advance `_carouselIndex`.
5. `_carouselIndex` — текущий индекс в `featured` массиве.
6. `_isWatchFocused: bool` — отдельный флаг для блокировки carousel'я
   когда Watch именно нажат фокусом (внутри `CinematicHeroBlock`
   onWatchFocusChanged).
7. Hover/preview chain: `_hoveredItem`, `_previewTimer`,
   `_hoveredClearDebounce`, `_previewingItem`, `_isPreviewPlaying`,
   `_isPreviewVideoReady`, `_previewPlayer`, `_previewStateSub`,
   `_hoverSettleDelay = 600ms`.
8. Boot overlay: `_showBootOverlay`, `_bootFadeOut`, `_bootError`,
   `_bootUrlController`, `_runHomeBootstrap`, `_onBootRetryConnect`,
   `_onBootFadeOutEnded`, `_scheduleHeroWatchFocus`.
9. Clock: `_clockTimer = Timer.periodic(30s)`, `_clockTime`.

Любой из этих кусков, потерянный при рефакторе, — регрессия. План
рефакторинга должен **сохранять весь state в `_CinematicHomeScreenState`**
и переносить только site-of-use (куда монтируется hero widget).

### CinemaRow — текущий API

`CinemaRow({title, items, onItemTap, onItemFocus?, availableHeight?,
onLoadMore?, wrapAround = false})`. Рендерит `AnimatedContainer(height:
availableHeight ?? 450.h)` → `Column[header, Expanded(Stack[ListView,
fadeOverlay])]`. ListView строится через `itemBuilder(context, index)`,
который для каждого индекса возвращает:

```
Focus(
  key: ValueKey('${channelId}_$index'),
  onFocusChange: ...,
  onKeyEvent: ...,
  child: MouseRegion(
    onEnter/onExit no-op,
    child: Padding(
      EdgeInsets.only(right: isLast ? 0 : gap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowH = constraints.maxHeight;
          return Align(
            alignment: Alignment.bottomCenter,
            child: CinemaCard(
              key: ValueKey('card_${channelId}_$index'),
              item: items[index],
              isFocused: _focusedIndex == index,
              cardWidth: layout.cardW,
              cardHeight: rowH,
              onTap: () => onItemTap(items[index]),
            ),
          );
        },
      ),
    ),
  ),
)
```

**Ключевое наблюдение**: каждая плитка в `itemBuilder` обёрнута в
**Focus + MouseRegion + Padding + LayoutBuilder + Align + CinemaCard**.
Эта обёртка управляет focus pipeline (включая `_scrollFocusedTileToLeadingEdge`,
который реализует Pinned-Slot Invariant) и onLoadMore триггер.

Для подмены первой плитки на hero-tile widget нужно ослабить эту
обёртку для `index == 0` когда `firstSlot != null`: hero-tile widget
должен сам владеть своим Focus (потому что persistent FocusNode — это
часть его контракта, см. Req 4). Pinned-Slot scrolling для index 0
по-прежнему должен работать (потому что hero коллапсирует именно в
slot 0; pinned-slot scroll target — `(0 - 1) * (cardW + gap) = -(cardW+gap)`
которое clamp'ится в 0, то есть leading-edge clamp). Это означает: для
index 0 row scroll вызовется через **firstSlot's FocusNode.onFocusChange**
(который hero-tile widget exposes), либо row подписывается на
`firstSlot.focusNode` через известный seam.

Простейший вариант — `firstSlot` принимает не просто `Widget`, а
**пакет**: `firstSlot: FirstSlotSpec({Widget child, FocusNode focusNode})`.
Row слушает `focusNode.addListener(...)` для обновления `_focusedIndex`
и триггера `_scrollFocusedTileToLeadingEdge`. Это и читаемо, и не ломает
существующий контракт row для index ≥ 1.

### GridTokens — что уже доступно (после home-grid-stability-pass)

Upstream спек добавляет (по `tasks.md → 1.1`):

- `focusedScale = 1.01` (было 1.02).
- `pinnedSlotIdx = 1` (был хардкод в row).
- `cardHeightDp = 720` (заменяет `450.h` default).
- `metadataReservedHeightDp = 46`.
- `unfocusedNeighbourOpacity = 0.92`.

Pinned-Slot Invariant теперь документирован на `CinemaRow` dartdoc'е +
покрыт `cinema_row_pinned_slot_test.dart` (упоминается в upstream
tasks.md → 7.x).

**Ключевая инвариантность для нашего спека**: hero коллапсирует в
**слот 0** первой полосы (не слот 1). При focus на index 0 row будет
scroll до `offset = (0 - 1) * stride = -stride`, clamp в 0 → leading
edge. Hero-tile widget визуально оказывается на leading edge ряда. Это
естественно: пользователь видит hero как «первую плитку первой полосы»,
а Pinned-Slot контракт (pin to slot 1) применяется к плиткам index ≥ 1
которые сдвигаются под фокусом D-pad → вправо.

### TV-perf rules (актуальная редакция steering)

Из `flutter-tv-perf.md`:

- **Запрещено**: `BackdropFilter`, `ImageFilter.blur`, `ShaderMask`,
  `BoxShadow.blurRadius > 12`, `AnimatedContainer.width` для focus,
  тяжёлые SVG > 64 dp.
- **Разрешено**: `Transform.scale`, `AnimatedPositioned`, `Opacity` (с
  оговоркой «один Opacity на ряд приемлемо, over-uses дорого»),
  `AnimatedBuilder`, `TweenSequence`.
- **Leanback timings**: card focus 150ms, row scroll 250ms, OSD fade-in
  250ms, OSD fade-out 325ms.

Длительность morph 300ms попадает между card focus (150ms) и row scroll
(250ms), но ближе к OSD fade (325ms) — что соответствует «эстетическое
изменение состояния» а не «реакция на ввод». User feedback просил
«сдвиг», что подразумевает явную, чувствительную анимацию. 300ms
выбрано как **середина диапазона brief'а (280-350ms)**, удобный round
number, и кратно 60 fps кадрам (300/16.7 ≈ 18 кадров — достаточно для
плавности, не слишком долго).

## Альтернативы и обоснование решений

### Alt-1: AnimatedCrossFade с увеличенной длительностью

**Идея**: оставить `AnimatedCrossFade` но увеличить длительность с 220ms
до 300ms и заменить `SizedBox.shrink()` на компактную плитку.

**Отказ**:

- Cross-fade физически перерисовывает два дерева одновременно — два hero
  одновременно жить в дереве (даже на 1 кадр) нарушает Req 3.7 «no two
  parallel hero subtrees».
- Focus transfer через cross-fade требует `requestFocus()` после
  завершения (Req 4.4 запрещает).
- На промежуточном кадре visible = 50% / 50% → визуально читается как
  «чёрная дыра» при тёмной теме (Req 7.2 запрещает).
- User feedback: «появляется из чёрной пустоты» — это симптом
  cross-fade, который мы должны устранить, а не масштабировать.

### Alt-2: Hero widget (Flutter Hero / SharedAxisTransition)

**Идея**: использовать встроенный `Hero` widget или
`material_motion`-style shared axis transition.

**Отказ**:

- `Hero` рассчитан на route transitions, не на in-route morph. Внутри
  одного `Scaffold.body` Hero не активируется автоматически.
- `material_motion` потребует нового пакета в `pubspec.yaml`
  (`animations` package), что нарушает No-new-packages constraint.
- В обоих случаях невозможно поддержать single-source contract (Req 3.7):
  Hero создаёт overlay-копию виджета на время transition.

### Alt-3: ScrollController-driven hero collapse

**Идея**: hero высота = `clamp(620 - scrollOffset, collapsedH, 620)` —
hero сжимается пропорционально скроллу rails вниз.

**Отказ**:

- На TV нет «scroll», есть focus traversal. Rails — `ListView.builder`,
  но вертикальный его scroll не происходит, потому что rails монтируются
  через flat `ListView.builder` внутри `Positioned(top: 620)`.
- Hero collapse должен зависеть от **focus position** (rails focused vs
  hero focused), а не от scroll offset.

### Alt-4: Spring physics через `SpringSimulation`

**Идея**: использовать `AnimationController.animateWith(SpringSimulation(...))`
для bouncy feel.

**Отказ**:

- Req 2.3 запрещает spring physics.
- Spring duration зависит от velocity → недетерминированно → плохо для
  TV-перф измерений (avg frame time скачет).
- User feedback просил «сдвиг», не «отскок».

### Alt-5: Два независимых widget'а с `Visibility(maintainState: true)`

**Идея**: hero — `Visibility(visible: !collapsed, maintainState: true)` +
slot-0 tile — `Visibility(visible: collapsed, maintainState: true)`,
оба живут в дереве всегда, переключается видимость.

**Отказ**:

- `maintainState: true` означает оба subtree билдятся каждый кадр →
  cost растёт (Req 10.5 запрещает новые per-frame rebuilds).
- Нарушает Req 3.7 single-source: формально два subtree в дереве, даже
  если один скрыт.
- Focus transfer становится нетривиальным: invisible widget может
  держать focus, что ломает Req 4.5 «one node from mount to unmount».

### Chosen approach: Single widget HeroTileMorph + firstSlot API

Выбран **вариант a из brief'а**:

- HeroTileMorph — один stateful widget с persistent FocusNode и
  AnimationController.
- Два layout-режима внутри одного build: switch на `_controller.value`
  и `AnimationStatus`.
- Подаётся в CinemaRow через новый `firstSlot` параметр (опционально,
  back-compat по умолчанию).
- CinematicHomeScreen теряет `Positioned(top:0, height:620)` hero block;
  rails ListView начинается с `top: 0`, первая `CinemaRow` — единственная
  с `firstSlot != null`.

Преимущества:

- Single source of truth: один widget — один FocusNode — одно дерево.
- Focus transfer тривиален (Req 4 free-by-construction).
- Cross-fade устранён → Req 7 (no black gaps) гарантирован
  геометрически.
- Анимация — один AnimationController (Req 10.4).
- Pinned-Slot контракт работает естественно: pin slot 0 = leading edge,
  hero-tile сидит на leading edge expanded или collapsed.

Сложности:

- Hero в expanded режиме должен **визуально выходить за верхнюю
  границу полосы** (потому что expanded hero = 620 dp, а CinemaRow row
  height = `cardHeightDp` ≈ 720 dp; но hero показывается **выше** rails,
  то есть его top = 0, а полоса top = expandedH — это в текущей
  архитектуре). После рефакторинга у нас нет «hero выше rails» — есть
  «hero в first row, и first row занимает 620+ dp в верхней части
  экрана».
- Это означает: первая `CinemaRow` имеет **уникальную высоту**: в
  expanded режиме = expandedH (620) для слота 0, в collapsed = cardHeightDp
  (720) для слота 0. Остальные плитки первой row рендерятся с обычным
  cardHeightDp всегда.
- Решение: `CinemaRow` с `firstSlot != null` использует **custom row
  height function**, которая берёт max(expandedH, cardHeightDp) когда
  hero expanded, и cardHeightDp когда hero collapsed. Сама row height
  может быть просто **`max(expandedHeroHeightDp, cardHeightDp)` всегда**
  — hero collapsed просто занимает меньше места в верхнем выровненном
  виде, остальные плитки выровнены по нижнему краю.

  Более простой вариант: первая `CinemaRow` высотой **`expandedHeroHeightDp`**
  всегда; hero-tile занимает всю эту высоту в expanded и cardHeightDp в
  collapsed (выровненный по нижнему краю); прочие плитки выровнены по
  нижнему краю (`Align(alignment: Alignment.bottomCenter, child: CinemaCard)`
  — уже так и есть в текущем itemBuilder).

  Этот вариант **back-compat**: остальные плитки видны вниз ряда,
  hero-tile в expanded режиме **накладывается сверху** и доминирует
  верхней частью экрана, в collapsed — компактно сидит в слоте 0
  выровненный по низу.

- Для **carousel timer** и **_isWatchFocused** flag — они продолжают
  жить в `_CinematicHomeScreenState`; HeroTileMorph принимает callbacks
  (`onWatchFocusChanged`, `onHeroFocusChange`) и `heroItem` как props.

## Открытые вопросы (для design phase)

### Q1: Какой именно `firstSlot` API на CinemaRow?

Кандидаты:

- **A**: `Widget? firstSlot` — простая подмена. Row сама строит
  Focus/Padding/Align вокруг.
- **B**: `WidgetBuilder? firstSlot` — builder, который получает
  `(context, slotConstraints)`. Так widget внутри сам решает как
  использовать constraints.
- **C**: новый класс `FirstSlotSpec({Widget child, FocusNode? focusNode,
  void Function(bool focused)? onFocusChange})`. Row знает про focusNode
  и слушает его для pinned-slot scroll.

**Выбор для design**: **B + опциональный focusNode параметр через
обёртку `FirstSlotConfig`** (вариация C). HeroTileMorph управляет
focus, row обязан слушать через переданный (или auto-detected) FocusNode
для триггера `_scrollFocusedTileToLeadingEdge(0)`. Финальная подпись API
конкретизируется в `design.md`.

### Q2: Где живут expanded hero внутренности (backdrop image, title, Watch button)?

Кандидаты:

- **A**: HeroTileMorph владеет ими полностью, копируя визуал из
  `CinematicHeroBlock`.
- **B**: HeroTileMorph принимает `Widget expandedChild` (= существующий
  `CinematicHeroBlock`) и `Widget collapsedChild` (= новый компонент
  поверх обычного `CinemaCard`).
- **C**: HeroTileMorph делегирует обе сборки через builder pattern.

**Выбор для design**: **B**. HeroTileMorph не пересобирает hero block
с нуля — он принимает уже готовый `CinematicHeroBlock` (передаётся
сверху из `CinematicHomeScreen`) и готовую тиле-компактную репрезентацию
(аналог `CinematicCompactHero` но в виде тиле). Это минимизирует
дублирование: `CinematicHeroBlock` уже имеет все нужные внутренности
(backdrop, title, Watch button, focus node Watch). Опасность: внутри
`CinematicHeroBlock` уже есть свой `heroWatchFocusNode` — в новой
архитектуре persistent FocusNode HeroTileMorph должен **либо обёртывать
WatchFocusNode**, либо просто **проксировать** существующий focus
listener.

### Q3: Что с `_heroWatchFocusNode` после рефакторинга?

`_heroWatchFocusNode` существует на уровне `_CinematicHomeScreenState`
и слушается `_onHeroWatchFocusChanged`. В новой архитектуре persistent
FocusNode живёт **внутри** HeroTileMorph. Варианты:

- **A**: HeroTileMorph принимает `FocusNode externalNode` от родителя
  (`_heroWatchFocusNode`) — родитель остаётся owner'ом.
- **B**: HeroTileMorph создаёт свой `FocusNode internalNode` и
  `CinematicHomeScreen` слушает его через переданный callback
  `onHeroFocusChange(bool)`.

**Выбор для design**: **A**. `_heroWatchFocusNode` уже владеется
`_CinematicHomeScreenState`, имеет правильный disposal, его слушает
`_onHeroWatchFocusChanged`. HeroTileMorph принимает его как `focusNode`
prop и применяет к Watch button в expanded режиме / к корневому tile в
collapsed режиме. Persistent contract выполняется: один и тот же
FocusNode живёт сквозь все 4 состояния. Req 4.5 удовлетворён.

### Q4: Как тестировать state machine?

Кандидаты:

- **A**: Unit-test через прямой инстанс state-машины (если она
  изолирована в чистый класс).
- **B**: Widget-test через `tester.pumpWidget(HeroTileMorph(...))` +
  semantic assertions через `find.byKey` / `find.bySemanticsLabel`.
- **C**: Golden-test ключевых кадров (controller.value = 0, 0.25, 0.5,
  0.75, 1.0).

**Выбор для design**: **A для state machine + B для focus survival**.
State machine моделируется как pure-enum `HeroMorphState` + transitions
функция; unit-test проверяет переходы (forward, reverse, mid-flight
reverse, disableAnimations snap). Focus survival — widget-test:
`tester.pumpWidget(...)`, drive focus, цикл collapse→expand,
`expect(focusNode.hasFocus, true)` после каждого pump'а. Golden-test —
**не делаем** в этой фазе (вынесено в visual-feedback-pipeline downstream
spec).

### Q5: macOS debug build — почему именно macOS?

Brief упоминает «Manual smoke test checklist (macOS debug build)».
Проект — Flutter Android TV app; разработчик работает на macOS, и
debug build на macOS desktop — самый быстрый цикл для визуальной
проверки до коммита. Smoke checklist должен быть applicable к macOS
desktop window: D-pad через keyboard arrows, фокус на Watch button,
визуальная проверка morph в обе стороны, accessibility toggle через
системные настройки macOS «Reduce motion». TV smoke на rtd2851a —
отдельно после macOS smoke.

## Источники

- `brief.md` — оригинальный problem statement, user feedback, scope.
- `.kiro/specs/home-grid-stability-pass/design.md` — upstream contract:
  `cardHeightDp`, `pinnedSlotIdx`, `focusedScale`, Pinned-Slot Invariant.
- `.kiro/specs/home-grid-stability-pass/requirements.md` — user-observable
  инварианты upstream.
- `.kiro/specs/home-grid-stability-pass/tasks.md` — конкретные числовые
  значения, которые будут в коде к моменту start этого спека.
- `.kiro/steering/flutter-tv-perf.md` — TV-perf rules, allowed/forbidden
  API list, Leanback timings.
- `.kiro/steering/roadmap.md` — Polish Cycle 2026 execution order.
- `megav_iptv/lib/features/home/cinematic/cinematic_home_screen.dart` —
  текущая структура hero + rails + focus pipeline.
- `megav_iptv/lib/features/home/widgets/cinema_row.dart` — текущий
  itemBuilder, focus pipeline, pinned-slot scroll.
- `megav_iptv/lib/features/home/widgets/_grid_tokens.dart` — текущая
  редакция токенов (до home-grid-stability-pass).
