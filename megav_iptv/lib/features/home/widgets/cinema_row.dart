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

  @override
  void didUpdateWidget(CinemaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocusedRow && widget.focusedCol >= 0) {
      _scrollToIndex(widget.focusedCol);
      if (widget.onLoadMore != null && widget.focusedCol >= widget.items.length - 3) {
        widget.onLoadMore!();
      }
    }
  }

  double _computeCardWidth() {
    final titleBarHeight = 16.h + 8.h + 20.sp;
    final totalHeight = widget.availableHeight ?? 360.h;
    return (totalHeight - titleBarHeight) * 0.6;
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final cw = _computeCardWidth() + 12.w;
    final targetOffset = (index * cw) - 80.w;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
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

    final titleBarHeight = 16.h + 8.h + 20.sp;
    final totalHeight = widget.availableHeight ?? 360.h;
    final cardListHeight = totalHeight - titleBarHeight;
    final cardWidth = cardListHeight * 0.6;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: totalHeight,
      color: widget.isFocusedRow ? Colors.white.withValues(alpha: 0.015) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(32.w, 16.h, 32.w, 8.h),
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
              cacheExtent: 400,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final isFocused = widget.isFocusedRow && index == widget.focusedCol.clamp(0, widget.items.length - 1);
                return Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: CinemaCard(
                    item: widget.items[index],
                    isFocused: isFocused,
                    cardWidth: cardWidth,
                    cardHeight: cardListHeight,
                    onTap: () => widget.onItemTap(widget.items[index]),
                    onFocusChange: (focused) {
                      widget.onItemFocus?.call(focused ? widget.items[index] : null);
                    },
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
