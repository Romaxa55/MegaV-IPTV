import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/utils/fast_scroll_detector.dart';
import '../cinematic/hero_tile_morph.dart' show FirstSlotConfig;
import '_cinema_row_loading.dart';
import '_grid_tokens.dart';
import 'cinema_card.dart';

void _precacheRowPosters(BuildContext context, List<NowPlayingItem> items, {int max = 28}) {
  for (final item in items.take(max)) {
    final u = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
    if (u == null || u.isEmpty) continue;
    unawaited(precacheImage(NetworkImage(u), context));
  }
}

/// Wrapper that fetches paginated data for a category row.
class CategoryRowWrapper extends ConsumerStatefulWidget {
  final CinemaCategory category;
  final void Function(NowPlayingItem item) onItemTap;
  final void Function(NowPlayingItem? item)? onItemFocus;

  /// Optional slot-0 override (see [FirstSlotConfig]).
  final FirstSlotConfig? firstSlot;

  const CategoryRowWrapper({
    super.key,
    required this.category,
    required this.onItemTap,
    this.onItemFocus,
    this.firstSlot,
  });

  @override
  ConsumerState<CategoryRowWrapper> createState() => _CategoryRowWrapperState();
}

class _CategoryRowWrapperState extends ConsumerState<CategoryRowWrapper> {
  /// Bumps when the visible prefix of the row changes (new data / pagination) so we precache again.
  int _precacheSignature = 0;

  void _schedulePrecache(BuildContext context, List<NowPlayingItem> list) {
    if (list.isEmpty) return;
    final sig = Object.hash(
      list.length,
      list.first.channelId,
      list.length > 1 ? list[list.length ~/ 2].channelId : 0,
      list.last.channelId,
    );
    if (sig == _precacheSignature) return;
    _precacheSignature = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheRowPosters(context, list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMoviesRow = widget.category.id == 'live-movies';
    final provider = isMoviesRow ? moviesNotifierProvider : categoryNotifierProvider(widget.category.name);
    final asyncData = ref.watch(provider);

    ref.listen<AsyncValue<List<NowPlayingItem>>>(provider, (previous, next) {
      next.whenData((list) => _schedulePrecache(context, list));
    });

    final items = asyncData.value ?? [];
    if (items.isNotEmpty) {
      _schedulePrecache(context, items);
    }

    if (asyncData.isLoading && !asyncData.hasValue) {
      return CinemaRowLoadingPlaceholder(title: widget.category.name);
    }

    if (items.isEmpty && asyncData.hasError) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
        child: Text(
          'Не удалось загрузить ряд',
          style: TextStyle(fontSize: TS.xs.sp, color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }

    return CinemaRow(
      title: widget.category.name,
      items: items,
      wrapAround: isMoviesRow,
      onLoadMore: isMoviesRow
          ? () => ref.read(moviesNotifierProvider.notifier).loadMore()
          : () => ref.read(categoryNotifierProvider(widget.category.name).notifier).loadMore(),
      onItemTap: widget.onItemTap,
      onItemFocus: widget.onItemFocus,
      firstSlot: widget.firstSlot,
    );
  }
}

/// Horizontal carousel-row widget for the home screen tile grid.
///
/// ## Pinned-Slot Invariant (home-grid-stability-pass spec)
///
/// The row implements a strict Netflix/Apple-TV-style focus pattern: the
/// **focused tile's screen-space horizontal position stays constant** as
/// the user sweeps D-pad ←/→, with tolerance ±1.0 dp. Conceptually the
/// grid "stands still" and the items slide through it, instead of the
/// focused tile chasing the focus across the screen.
///
/// Formally:
///
/// 1. **Middle traversal** — for every index `i` such that
///    `GridTokens.pinnedSlotIdx ≤ i ≤ N - (visibleCount - pinnedSlotIdx)`,
///    when the focused index transitions `i → i+1` or `i → i-1`, the
///    screen-space `localToGlobal(Offset.zero)` of the focused tile
///    differs from the previous step by `≤ 1.0` dp on the X axis.
///
/// 2. **Leading-edge clamp** — for `i ∈ [0, pinnedSlotIdx]` the
///    `ScrollController.offset` is forced to `0` (the row does not scroll
///    into negative offsets). The focused tile moves freely in screen
///    space until the user crosses `pinnedSlotIdx`.
///
/// 3. **Trailing-edge clamp** — for the last `(visibleCount - pinnedSlotIdx)`
///    tiles the `ScrollController.offset` is forced to `maxScrollExtent`
///    (the row does not over-scroll past the rightmost tile). The focused
///    tile resumes moving in screen space toward the right edge.
///
/// 4. **Tolerance** — ±1.0 dp on all measured offsets; this absorbs
///    rounding from `flutter_screenutil`'s `.w/.h` density conversion.
///
/// Implemented by `_scrollFocusedTileToLeadingEdge` which clamps
/// `(index - GridTokens.pinnedSlotIdx) * cardStride` to
/// `[0, maxScrollExtent]`.
///
/// Verifiable contract: `test/features/home/widgets/cinema_row_pinned_slot_test.dart`
/// (three test cases corresponding to clauses 1, 2, 3 above).
///
/// ## Boundary
///
/// This dartdoc was introduced by spec `home-grid-stability-pass` (not
/// `home-grid-optimization`, which owns the algorithm itself). The
/// stability pass does NOT modify `_scrollFocusedTileToLeadingEdge` —
/// it only formalises and tests the invariant that was already emerging.
class CinemaRow extends StatefulWidget {
  final String title;
  final List<NowPlayingItem> items;
  final void Function(NowPlayingItem item) onItemTap;

  /// Вызывается ПОСЛЕ debounce 400 мс стабильного фокуса (Req 4.1, 4.2, 10.5).
  /// `null`-clear при потере фокуса — синхронный, без debounce.
  final void Function(NowPlayingItem? item)? onItemFocus;
  final double? availableHeight;
  final VoidCallback? onLoadMore;
  final bool wrapAround;

  /// Optional override for slot-0 rendering (see [FirstSlotConfig]).
  /// Owned by hero-collapse-tile-morph spec; null = regular rendering.
  final FirstSlotConfig? firstSlot;

  const CinemaRow({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onItemFocus,
    this.availableHeight,
    this.onLoadMore,
    this.wrapAround = false,
    this.firstSlot,
  });

  @override
  State<CinemaRow> createState() => _CinemaRowState();
}

class _CinemaRowState extends State<CinemaRow> {
  final ScrollController _scrollController = ScrollController();

  /// Один источник истины для фокуса в ряду. `-1` если фокус вне ряда.
  /// (Req 3.6, 4.1) — заменяет старую тройку `_hoveredCol`/`_focusedCol`/`_lastActiveCol`.
  int _focusedIndex = -1;

  /// Debounce-таймер: вызов `widget.onItemFocus(item)` задержан на 400 мс
  /// от последнего стабильного фокуса (Req 4.1, 4.2, 10.5).
  Timer? _focusStableTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.onLoadMore == null || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      widget.onLoadMore!();
    }
  }

  /// Геометрия сетки для текущей ширины экрана.
  /// `n` — число колонок (3/4/5), `cardW` — общая ширина каждой плитки.
  ({int n, double cardW}) _gridLayoutFor(double screenW) {
    final n = pickColumns(screenW);
    final pad = GridTokens.horizontalPaddingDp.w;
    final gap = GridTokens.gapDp.w;
    final usable = screenW - 2 * pad - (n - 1) * gap;
    final cardW = usable > 0 ? usable / n : 200.0;
    return (n: n, cardW: cardW);
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(0.0, max),
      duration: GridTokens.scrollAnimation,
      curve: GridTokens.scrollCurve,
    );
  }

  /// Netflix/Leanback: прижимает focused-плитку к левому краю видимой области.
  ///
  /// При фиксированной ширине offset считается арифметически:
  /// `offset = index * (cardW + gap)`. Анимация — 250 мс с `fastOutSlowIn`
  /// (Req 2.1, 2.2, 2.3, 7.3, 7.5).
  ///
  /// Guard для Req 2.4: если плитка уже левее или на самой leading edge —
  /// не двигаем скролл назад.
  void _scrollFocusedTileToLeadingEdge(int index) {
    if (!_scrollController.hasClients || index < 0 || index >= widget.items.length) {
      return;
    }
    final screenW = MediaQuery.sizeOf(context).width;
    final layout = _gridLayoutFor(screenW);
    final gap = GridTokens.gapDp.w;
    // Netflix-style: keep the focused tile pinned to slot GridTokens.pinnedSlotIdx
    // (currently 1) so the user always sees one "previous" tile to the left,
    // providing spatial context. The grid stays put while items animate
    // through it. See the "Pinned-Slot Invariant" dartdoc on `CinemaRow`
    // for the formal contract this code implements.
    final cardStride = layout.cardW + gap;
    final targetOffset = (index - GridTokens.pinnedSlotIdx) * cardStride;
    final max = _scrollController.position.maxScrollExtent;
    final clamped = targetOffset.clamp(0.0, max);
    final current = _scrollController.offset;

    // Skip when target == current (already pinned correctly).
    if ((clamped - current).abs() < 0.5) return;
    _scrollController.animateTo(clamped, duration: GridTokens.scrollAnimation, curve: GridTokens.scrollCurve);
  }

  /// Запускает debounce 400 мс на dispatch `widget.onItemFocus(item)`.
  /// Если до истечения таймера фокус сместится — таймер перезапустится
  /// (через cancel в _onTileFocusChanged).
  void _scheduleStableFocus(int index) {
    _focusStableTimer?.cancel();
    _focusStableTimer = Timer(GridTokens.focusStableDebounce, () {
      if (!mounted) return;
      if (_focusedIndex != index) return;
      if (index < 0 || index >= widget.items.length) return;
      widget.onItemFocus?.call(widget.items[index]);
    });
  }

  @override
  void dispose() {
    _focusStableTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.sizeOf(context).width;
    final layout = _gridLayoutFor(screenW);
    final isRowFocused = _focusedIndex >= 0;

    return AnimatedContainer(
      duration: GridTokens.focusAnimation,
      height: widget.availableHeight ?? GridTokens.cardHeightDp.h,
      color: isRowFocused ? Colors.white.withValues(alpha: 0.018) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Шапка остаётся на 40.w — оставляем визуально привычный отступ
            // заголовка (см. CONCERNS в отчёте). Tile-зона использует
            // GridTokens.horizontalPaddingDp.w (=48.w) — небольшое расхождение
            // намеренное.
            padding: EdgeInsets.fromLTRB(40.w, 16.h, 40.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.title == 'Фильмы в эфире') ...[
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB2C36).withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isRowFocused ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${widget.items.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const Spacer(),
                _ChevronButton(icon: Icons.chevron_left, onTap: () => _scrollBy(-600.w)),
                SizedBox(width: 6.w),
                _ChevronButton(icon: Icons.chevron_right, onTap: () => _scrollBy(600.w)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // Поднимаем вьюпорт списка вверх: scale активной карточки
                // не режется заголовком ряда и границей Expanded.
                Positioned(
                  left: 0,
                  right: 0,
                  top: -72.h,
                  bottom: 0,
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.only(
                        left: GridTokens.horizontalPaddingDp.w,
                        right: GridTokens.horizontalPaddingDp.w,
                        top: 56.h,
                        bottom: 24.h,
                      ),
                      cacheExtent: 1500.w, // Увеличено для рендера виджетов за экраном
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final isFocused = _focusedIndex == index;
                        final isLast = index == widget.items.length - 1;

                        return Focus(
                          key: ValueKey('${widget.items[index].channelId}_$index'),
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              FastScrollDetector().onEvent();
                              setState(() {
                                _focusedIndex = index;
                              });

                              // Пагинация — синхронно, debounce'у не подлежит
                              // (Req 8.2).
                              if (widget.onLoadMore != null && index >= widget.items.length - 3) {
                                widget.onLoadMore!();
                              }

                              // Heavy onItemFocus dispatch — через debounce
                              // 400 мс (Req 4.1, 4.2, 10.5). Scale в карточке
                              // запускается мгновенно через isFocused (Req 4.3).
                              _scheduleStableFocus(index);

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted || _focusedIndex != index) return;
                                _scrollFocusedTileToLeadingEdge(index);
                              });
                            } else if (_focusedIndex == index) {
                              // null-clear синхронный (без debounce) — Hero
                              // должен мгновенно понять, что фокус ушёл.
                              _focusStableTimer?.cancel();
                              setState(() => _focusedIndex = -1);
                              widget.onItemFocus?.call(null);
                            }
                          },
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            final key = event.logicalKey;
                            if (key == LogicalKeyboardKey.select ||
                                key == LogicalKeyboardKey.enter ||
                                key == LogicalKeyboardKey.gameButtonA ||
                                key == LogicalKeyboardKey.numpadEnter) {
                              widget.onItemTap(widget.items[index]);
                              return KeyEventResult.handled;
                            }
                            // Req 10.2: на последней плитке стрелка вправо
                            // не уводит фокус.
                            if (isLast && key == LogicalKeyboardKey.arrowRight) {
                              return KeyEventResult.handled;
                            }
                            // ESC/BACK и всё остальное — родителю.
                            return KeyEventResult.ignored;
                          },
                          child: MouseRegion(
                            // Hover-эффекты ушли в общий focus-pipeline.
                            // На TV-таргете мышь редка; для desktop оставляем
                            // no-op — focus всё равно дойдёт через pointer-tap
                            // и WidgetOrderTraversalPolicy. См. CONCERNS.
                            onEnter: (_) {},
                            onExit: (_) {},
                            child: Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : GridTokens.gapDp.w),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final rowH = constraints.maxHeight;
                                  // home-grid-stability-pass req 2.2, 2.5, 6.1:
                                  // soft-damp the unfocused neighbours WITHIN
                                  // the active row only. When the row has no
                                  // focus at all (_focusedIndex == -1) every
                                  // tile renders at full opacity so adjacent
                                  // rows look untouched. Opacity is TV-perf
                                  // safe under Impeller (single blend pass).
                                  final isRowActiveAndUnfocused = isRowFocused && !isFocused;
                                  final tileOpacity = isRowActiveAndUnfocused
                                      ? GridTokens.unfocusedNeighbourOpacity
                                      : 1.0;
                                  return Opacity(
                                    opacity: tileOpacity,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: CinemaCard(
                                        key: ValueKey('card_${widget.items[index].channelId}_$index'),
                                        item: widget.items[index],
                                        isFocused: isFocused,
                                        cardWidth: layout.cardW,
                                        cardHeight: rowH,
                                        onTap: () => widget.onItemTap(widget.items[index]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Cheap right-edge fade overlay (Req 1.1, 1.2, 1.3, 1.4, 1.5).
                // Заменяет ShaderMask + BlendMode.dstOut, который компилировал
                // GL shader (260 ms jank) и платил saveLayer на полную ширину
                // ряда каждый кадр. Здесь — обычный alpha-blended Positioned с
                // LinearGradient (transparent → AppColors.background) на правые
                // ~5% ширины: GPU-стоимость < 0.5 ms vs 26 ms у ShaderMask.
                // Левый край не затухает естественно (overlay только справа).
                Positioned(
                  right: 0,
                  top: -72.h,
                  bottom: 0,
                  width: MediaQuery.sizeOf(context).width * GridTokens.fadeEdgeFraction,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [const Color(0x0008080F), AppColors.background],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ChevronButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Icon(icon, size: 24.sp, color: Colors.white.withValues(alpha: 0.40)),
      ),
    );
  }
}
