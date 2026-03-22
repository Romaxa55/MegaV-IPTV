import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'cinema_card.dart';

/// Wrapper that fetches paginated data for a category row.
class CategoryRowWrapper extends ConsumerWidget {
  final CinemaCategory category;
  final void Function(NowPlayingItem item) onItemTap;
  final void Function(NowPlayingItem? item)? onItemFocus;

  const CategoryRowWrapper({super.key, required this.category, required this.onItemTap, this.onItemFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMoviesRow = category.id == 'live-movies';
    final asyncData = isMoviesRow
        ? ref.watch(moviesNotifierProvider)
        : ref.watch(categoryNotifierProvider(category.name));

    final items = asyncData.value ?? [];

    return CinemaRow(
      title: category.name,
      items: items,
      wrapAround: isMoviesRow,
      onLoadMore: isMoviesRow
          ? () => ref.read(moviesNotifierProvider.notifier).loadMore()
          : () => ref.read(categoryNotifierProvider(category.name).notifier).loadMore(),
      onItemTap: onItemTap,
      onItemFocus: onItemFocus,
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
  static const double _gap = 12;

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
    final horizontalPadding = 64.w;
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

    final titleBarHeight = 14.h + 6.h + 18.sp;
    final totalHeight = widget.availableHeight ?? 360.h;
    final maxCardHeight = totalHeight - titleBarHeight;

    final screenW = MediaQuery.of(context).size.width;
    final horizontalPadding = 64.w;
    final sizes = _cardSizes(screenW, horizontalPadding);

    final cardListHeight = maxCardHeight * _cardHeightPercent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: totalHeight,
      color: _isFocusedRow ? Colors.white.withValues(alpha: 0.015) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: titleBarHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(32.w, 14.h, 32.w, 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: TS.xs.sp,
                        fontWeight: FontWeight.w500,
                        color: _isFocusedRow
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${widget.items.length}',
                    style: TextStyle(fontSize: TS.t10.sp, color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  SizedBox(width: 12.w),
                  _ChevronButton(icon: Icons.chevron_left, onTap: () => _scrollBy(-400.w)),
                  SizedBox(width: 4.w),
                  _ChevronButton(icon: Icons.chevron_right, onTap: () => _scrollBy(400.w)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: cardListHeight,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              cacheExtent: 150,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final active = _activeCol;
                final isExpanded = index == active;
                final isFocused = _focusedCol == index || (_hoveredCol == index && isExpanded);
                final w = isExpanded ? sizes.fullW : sizes.narrowW;

                return Focus(
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
                        item: widget.items[index],
                        isFocused: isFocused,
                        cardWidth: w,
                        posterWidth: sizes.fullW,
                        cardHeight: cardListHeight,
                        expanded: isExpanded,
                        onTap: () => widget.onItemTap(widget.items[index]),
                      ),
                    ),
                  ),
                );
              },
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
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Icon(icon, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.25)),
      ),
    );
  }
}
