import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import 'cinema_card.dart';

class CinemaRow extends StatefulWidget {
  final String title;
  final List<NowPlayingItem> items;
  final bool isFocusedRow;
  final int focusedCol;
  final void Function(NowPlayingItem item) onItemTap;
  final void Function(NowPlayingItem? item)? onItemFocus;
  final double? availableHeight;
  final VoidCallback? onLoadMore;
  final bool wrapAround;

  const CinemaRow({
    super.key,
    required this.title,
    required this.items,
    this.isFocusedRow = false,
    this.focusedCol = -1,
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

  static const double _gap = 8;
  static const int _visibleNarrow = 5;
  static const double _narrowCropRatio = 0.55;

  int get _activeCol {
    if (_hoveredCol >= 0) return _hoveredCol;
    if (widget.isFocusedRow && widget.focusedCol >= 0) {
      return widget.focusedCol.clamp(0, widget.items.length - 1);
    }
    return 0;
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

  @override
  void didUpdateWidget(CinemaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocusedRow && widget.focusedCol >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      if (widget.onLoadMore != null && widget.focusedCol >= widget.items.length - 3) {
        widget.onLoadMore!();
      }
    }
  }

  ({double fullW, double narrowW}) _cardSizes(double screenW) {
    final padH = 32.w;
    final usable = screenW - padH * 2;
    final totalGaps = _gap * _visibleNarrow;
    final fullW = (usable - totalGaps) / (_narrowCropRatio * (_visibleNarrow - 1) + 1);
    final narrowW = fullW * _narrowCropRatio;
    return (fullW: fullW, narrowW: narrowW);
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;
    final col = widget.focusedCol.clamp(0, widget.items.length - 1);
    final screenW = MediaQuery.of(context).size.width;
    final sizes = _cardSizes(screenW);

    double offset = 0;
    for (int i = 0; i < col; i++) {
      offset += sizes.narrowW + _gap;
    }

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
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
    final cardListHeight = totalHeight - titleBarHeight;

    final screenW = MediaQuery.of(context).size.width;
    final sizes = _cardSizes(screenW);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: totalHeight,
      color: widget.isFocusedRow ? Colors.white.withValues(alpha: 0.015) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(32.w, 14.h, 32.w, 6.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: TS.xs.sp,
                      fontWeight: FontWeight.w500,
                      color: widget.isFocusedRow
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
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              cacheExtent: 600,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final active = _activeCol;
                final isExpanded = index == active;
                final isFocused = (widget.isFocusedRow || _hoveredCol >= 0) && isExpanded;
                final w = isExpanded ? sizes.fullW : sizes.narrowW;

                return MouseRegion(
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
