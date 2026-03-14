import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/theme/app_colors.dart';
import 'channel_card.dart';

class ContentRow extends StatefulWidget {
  final String title;
  final List<Channel> channels;
  final bool isFocusedRow;
  final int focusedCol;
  final void Function(Channel channel, int index) onChannelTap;
  final void Function(Channel channel)? onChannelFocus;

  const ContentRow({
    super.key,
    required this.title,
    required this.channels,
    this.isFocusedRow = false,
    this.focusedCol = -1,
    required this.onChannelTap,
    this.onChannelFocus,
  });

  @override
  State<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends State<ContentRow> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(ContentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocusedRow && widget.focusedCol >= 0) {
      _scrollToIndex(widget.focusedCol);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final cardWidth = 220.w + 12.w;
    final targetOffset = (index * cardWidth) - 80.w;
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
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: widget.isFocusedRow ? Colors.white.withValues(alpha: 0.015) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(32.w, 16.h, 32.w, 8.h),
            child: Row(
              children: [
                Text('🔴', style: TextStyle(fontSize: TS.xs.sp)),
                SizedBox(width: 6.w),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: TS.xs.sp,
                    fontWeight: FontWeight.w500,
                    color: widget.isFocusedRow
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.chevron_right, size: TS.sm.sp, color: Colors.white.withValues(alpha: 0.15)),
                const Spacer(),
                _ChevronButton(icon: Icons.chevron_left, onTap: () => _scrollBy(-400.w)),
                SizedBox(width: 4.w),
                _ChevronButton(icon: Icons.chevron_right, onTap: () => _scrollBy(400.w)),
              ],
            ),
          ),
          SizedBox(
            height: 200.h,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final isFocused =
                    widget.isFocusedRow && index == widget.focusedCol.clamp(0, widget.channels.length - 1);
                return Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: CinemaCard(
                    channel: widget.channels[index],
                    isFocused: isFocused,
                    onTap: () => widget.onChannelTap(widget.channels[index], index),
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
