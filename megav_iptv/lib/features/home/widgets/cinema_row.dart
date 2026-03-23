import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'cinema_card.dart';

void _precacheRowPosters(BuildContext context, List<NowPlayingItem> items, {int max = 28}) {
  for (final item in items.take(max)) {
    final u = item.thumbnailUrl ?? item.program.icon ?? item.logoUrl;
    if (u == null || u.isEmpty) continue;
    unawaited(precacheImage(NetworkImage(u), context));
  }
}

/// Wrapper that fetches paginated data for a category row.
class CategoryRowWrapper extends ConsumerStatefulWidget {
  final CinemaCategory category;
  final void Function(NowPlayingItem item) onItemTap;
  final void Function(NowPlayingItem? item)? onItemFocus;

  const CategoryRowWrapper({super.key, required this.category, required this.onItemTap, this.onItemFocus});

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
      return _CinemaRowLoadingPlaceholder(title: widget.category.name);
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
    );
  }
}

/// Same vertical space as a loaded row — avoids layout jump; greys instead of empty flash.
class _CinemaRowLoadingPlaceholder extends StatelessWidget {
  final String title;
  const _CinemaRowLoadingPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    final titleBarHeight = 14.h + 6.h + 18.sp;
    final cardListHeight = 220.h;
    return SizedBox(
      height: titleBarHeight + cardListHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: titleBarHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(40.w, 12.h, 40.w, 8.h),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: TS.xl.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          SizedBox(
            height: cardListHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Row(
                children: List.generate(
                  7,
                  (i) => Padding(
                    padding: EdgeInsets.only(right: 24.w),
                    child: Container(
                      width: 88.w,
                      height: cardListHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CinemaRow extends StatefulWidget {
  final String title;
  final List<NowPlayingItem> items;
  final void Function(NowPlayingItem item) onItemTap;
  final void Function(NowPlayingItem? item)? onItemFocus;
  final double? availableHeight;
  final VoidCallback? onLoadMore;
  final bool wrapAround;

  const CinemaRow({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onItemFocus,
    this.availableHeight,
    this.onLoadMore,
    this.wrapAround = false,
  });

  @override
  State<CinemaRow> createState() => _CinemaRowState();
}

class _CinemaRowState extends State<CinemaRow> {
  final ScrollController _scrollController = ScrollController();
  int _hoveredCol = -1;
  int _focusedCol = -1;

  static const double _cardHeightPercent = 1.0;
  static const double _gap = 24;

  bool get _isFocusedRow => _focusedCol >= 0;

  int get _activeCol {
    if (_hoveredCol >= 0) return _hoveredCol;
    if (_focusedCol >= 0) return _focusedCol;
    return 0; // Netflix-style: default to first item expanded
  }

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

  ({double fullW, double narrowW}) _cardSizes(double screenW, double horizontalPadding) {
    const gap = _gap;
    final usableWidth = screenW - horizontalPadding - 4 * gap;
    if (usableWidth <= 0) return (fullW: 200, narrowW: 100);
    final narrowW = usableWidth / 6;
    final fullW = narrowW * 2;
    return (fullW: fullW, narrowW: narrowW);
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Netflix-style: keep the focused card aligned to the **left** of the row (not centered by
  /// [Scrollable.ensureVisible], which felt random on TV).
  void _scrollFocusedCardToLeadingEdge(int index) {
    if (!_scrollController.hasClients || index < 0 || index >= widget.items.length) return;

    final screenW = MediaQuery.sizeOf(context).width;
    final horizontalPadding = 80.w;
    final sizes = _cardSizes(screenW, horizontalPadding);

    // Only [index] is expanded; all items before it are narrow — matches layout after setState.
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += sizes.narrowW + _gap;
    }

    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      offset.clamp(0.0, max),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    final horizontalPadding = 80.w;
    final sizes = _cardSizes(screenW, horizontalPadding);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.availableHeight ?? 350.h,
      color: _isFocusedRow ? Colors.white.withValues(alpha: 0.018) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(40.w, 16.h, 40.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _isFocusedRow ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.60),
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
            child: FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                cacheExtent: 400,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final active = _activeCol;
                  final isExpanded = index == active;
                  final isFocused = _focusedCol == index || (_hoveredCol == index && isExpanded);
                  final w = isExpanded ? sizes.fullW : sizes.narrowW;

                  return Focus(
                    key: ValueKey('${widget.items[index].channelId}_$index'),
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        setState(() => _focusedCol = index);
                        widget.onItemFocus?.call(widget.items[index]);

                        if (widget.onLoadMore != null && index >= widget.items.length - 3) {
                          widget.onLoadMore!();
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || _focusedCol != index) return;
                          _scrollFocusedCardToLeadingEdge(index);
                        });
                      } else if (_focusedCol == index) {
                        setState(() => _focusedCol = -1);
                        widget.onItemFocus?.call(null);
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      final key = event.logicalKey;
                      if (key == LogicalKeyboardKey.select ||
                          key == LogicalKeyboardKey.enter ||
                          key == LogicalKeyboardKey.gameButtonA ||
                          key == LogicalKeyboardKey.numpadEnter) {
                        widget.onItemTap(widget.items[index]);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: MouseRegion(
                      onEnter: (_) {
                        if (_hoveredCol != index) {
                          setState(() => _hoveredCol = index);
                          widget.onItemFocus?.call(widget.items[index]);
                        }
                      },
                      onExit: (_) {
                        if (_hoveredCol == index) {
                          setState(() => _hoveredCol = -1);
                          widget.onItemFocus?.call(null);
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: _gap),
                        child: CinemaCard(
                          key: ValueKey('card_${widget.items[index].channelId}_$index'),
                          item: widget.items[index],
                          isFocused: isFocused,
                          cardWidth: w,
                          posterWidth: sizes.fullW,
                          expanded: isExpanded,
                          onTap: () => widget.onItemTap(widget.items[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
