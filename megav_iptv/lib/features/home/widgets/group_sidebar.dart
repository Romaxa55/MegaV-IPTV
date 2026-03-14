import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel_group.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class GroupSidebar extends ConsumerWidget {
  final List<ChannelGroup> groups;

  const GroupSidebar({super.key, required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGroupProvider);

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Groups',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.cardBorder),
          Expanded(
            child: ListView.builder(
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _GroupTile(
                    name: 'All Channels',
                    count: groups.fold(0, (sum, g) => sum + g.channelCount),
                    isSelected: selected == null,
                    onTap: () => ref
                        .read(selectedGroupProvider.notifier)
                        .state = null,
                  );
                }
                final group = groups[index - 1];
                return _GroupTile(
                  name: group.name,
                  count: group.channelCount,
                  isSelected: selected == group.name,
                  onTap: () => ref
                      .read(selectedGroupProvider.notifier)
                      .state =
                      selected == group.name ? null : group.name,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatefulWidget {
  final String name;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTile({
    required this.name,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _isFocused;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isHighlighted ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isHighlighted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isHighlighted ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
