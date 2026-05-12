// home-unified-grid-scroll spec — Wave 5
//
// Единый вертикальный grid-scroller для главного экрана. Hero — row-0,
// cinema rows — row-1..N, опциональный footer — row-(N+1). Фокус
// намертво приколочен к screen-space строке
// `GridTokens.verticalPinnedSlotIdx`; стрелка ↑/↓ двигает grid, а не
// сам фокус.
//
// Этот файл заменяет прежнюю `Stack(Positioned(hero) + Positioned(rails))`
// архитектуру в `CinematicHomeScreen`. Hero collapse через
// `HeroTileMorph` отменён — hero просто скроллится за пределы viewport
// как обычная row.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/providers/providers.dart' show CinemaCategory;
import '../widgets/_grid_tokens.dart';
import 'hero_as_row.dart';

/// `UnifiedHomeGridScroller` — Vertical Pinned-Slot контейнер.
///
/// ## Vertical Pinned-Slot Invariant (формальный контракт)
///
/// 1. **Middle traversal** — для `focusedRowIdx ≥
///    GridTokens.verticalPinnedSlotIdx + 1` screen-space Y координата
///    focused row остаётся постоянной с tolerance `±1.0 dp` между
///    последовательными нажатиями D-pad ↑/↓. Это достигается
///    скроллом ListView к target offset, равному
///    `heroRowHeightDp + (focusedRowIdx - 2) * rowStrideDp` (math
///    учитывает что hero row выше обычной cinema row).
///
/// 2. **Leading-edge clamp** — для `focusedRowIdx ∈ {0, 1}` (hero
///    либо первая cinema row) target offset = 0. Это значит ↑ из
///    row-1 не выходит за начало списка; hero остаётся видна сверху.
///
/// 3. **Trailing-edge clamp** — последние строки прижимаются к
///    `_scrollController.position.maxScrollExtent`. Скроллить за
///    конец нельзя; визуально focused row может оказаться выше
///    pinned slot — это допустимое поведение когда строк меньше чем
///    `2 × verticalPinnedSlotIdx + 1`.
///
/// 4. **Tolerance** — `±1.0 dp` (как в горизонтальном invariant'е,
///    см. `CinemaRow`).
///
/// Тесты контракта: `test/features/home/cinematic/
/// unified_home_grid_scroller_test.dart`.
///
/// ## Math
///
/// Hero row высотой `heroRowHeightDp = 600 dp` ≠ cinema row высотой
/// `cardHeightDp = 720 dp` + `rowVerticalGapDp = 20 dp`. Vertical
/// scroll offset формируется как:
/// - hero (idx=0)         → 0
/// - cinemaRow (idx=1)    → 0
/// - cinemaRow (idx=i≥2)  → `heroRowHeightDp + (i - 2) * rowStrideDp`
///
/// Когда фокус заходит в row idx, `_animateToFocusedRow()` анимирует
/// `_scrollController` к target offset с `verticalScrollAnimation`
/// (250 ms) и `verticalScrollCurve` (easeInOutCubic).
///
/// ## Focus
///
/// Каждая row обёрнута в `Focus(skipTraversal: true,
/// onFocusChange: ...)` — он не участвует в traversal, но получает
/// callback когда любой descendant внутри row получает/теряет focus.
/// При получении focus row-idx запускается `_onRowFocused(idx)`.
///
/// `widget.heroFocusNode` (опционально) — если родитель хочет
/// держать «прямой» FocusNode на кнопке «Смотреть» внутри hero,
/// мы передаём его наружу. Сам scroller на этот node не listens —
/// row-0 focus detect-ится через тот же `Focus(skipTraversal:true)`
/// враппер.
class UnifiedHomeGridScroller extends StatefulWidget {
  const UnifiedHomeGridScroller({
    super.key,
    required this.heroBuilder,
    required this.categories,
    required this.rowBuilder,
    this.footer,
    this.heroFocusNode,
    this.onHeroFocusChanged,
  });

  /// Билдер для hero (row-0). Обычно возвращает `CinematicHeroBlock`.
  final WidgetBuilder heroBuilder;

  /// Список cinema-категорий — каждая становится row-1..N.
  final List<CinemaCategory> categories;

  /// Билдер для одной cinema row.
  final Widget Function(BuildContext, CinemaCategory) rowBuilder;

  /// Опциональный footer (например, remote-hint), идёт row-(N+1).
  final Widget? footer;

  /// Опциональный FocusNode для начального focus request (родительский
  /// `_scheduleHeroWatchFocus`). Сам scroller на listener этого node не
  /// подписывается — row-0 focus detect-ится через
  /// `Focus(skipTraversal:true)` обёртку вокруг hero.
  final FocusNode? heroFocusNode;

  /// Callback `(bool focused)` — вызывается когда focused row меняется
  /// между row-0 (hero) и не-hero. Используется родителем для
  /// pause/resume hero carousel.
  final ValueChanged<bool>? onHeroFocusChanged;

  @override
  State<UnifiedHomeGridScroller> createState() => _UnifiedHomeGridScrollerState();
}

class _UnifiedHomeGridScrollerState extends State<UnifiedHomeGridScroller> {
  late final ScrollController _scrollController;
  int _focusedRowIdx = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Vertical Pinned-Slot math ──────────────────────────────────────────────

  /// Возвращает target scroll offset для focused row `idx`.
  /// Clamping к `[0, maxScrollExtent]` гарантирует leading/trailing
  /// edge поведение.
  double _verticalOffsetForRow(int idx) {
    // Leading-edge clamp: focused row idx ∈ {0, 1} — hero видна.
    if (idx <= GridTokens.verticalPinnedSlotIdx) return 0.0;
    // Middle: hero уезжает наверх + cinema rows стекают.
    final raw = GridTokens.heroRowHeightDp.h + (idx - GridTokens.verticalPinnedSlotIdx - 1) * GridTokens.rowStrideDp.h;
    // Trailing-edge clamp (только если controller уже attached).
    if (!_scrollController.hasClients) return raw;
    final maxExtent = _scrollController.position.maxScrollExtent;
    return raw.clamp(0.0, maxExtent);
  }

  void _animateToFocusedRow() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _verticalOffsetForRow(_focusedRowIdx);
      if ((_scrollController.offset - target).abs() < 1.0) return;
      _scrollController.animateTo(
        target,
        duration: GridTokens.verticalScrollAnimation,
        curve: GridTokens.verticalScrollCurve,
      );
    });
  }

  void _onRowFocused(int idx) {
    if (idx == _focusedRowIdx) return;
    final wasHero = _focusedRowIdx == 0;
    final nowHero = idx == 0;
    setState(() => _focusedRowIdx = idx);
    _animateToFocusedRow();
    if (wasHero != nowHero) {
      widget.onHeroFocusChanged?.call(nowHero);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemCount = 1 + widget.categories.length + (widget.footer != null ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      // Каждая row — отдельная focus-зона. Внутренняя cinema row может
      // иметь свой ScrollController (horizontal), родительский vertical
      // ScrollController независим.
      cacheExtent: 1500.h,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: (ctx, idx) {
        Widget rowChild;
        if (idx == 0) {
          rowChild = HeroAsRow(child: widget.heroBuilder(ctx));
        } else if (idx <= widget.categories.length) {
          final cat = widget.categories[idx - 1];
          // Compact-row height задаётся caller'ом через rowBuilder →
          // CategoryRowWrapper(availableHeight: unifiedRowHeightDp.h).
          // Scroller сам не навязывает height — это позволяет caller'у
          // подобрать высоту под другой формат (например legacy постер).
          rowChild = Padding(
            padding: EdgeInsets.only(bottom: GridTokens.rowVerticalGapDp.h),
            child: widget.rowBuilder(ctx, cat),
          );
        } else {
          // footer row
          rowChild = widget.footer!;
        }

        // Каждая row завёрнута в Focus(skipTraversal:true) — не
        // участвует в traversal сам, но получает onFocusChange когда
        // любой descendant focused.
        return Focus(
          skipTraversal: true,
          canRequestFocus: false,
          onFocusChange: (focused) {
            if (focused) _onRowFocused(idx);
          },
          child: rowChild,
        );
      },
    );
  }
}
