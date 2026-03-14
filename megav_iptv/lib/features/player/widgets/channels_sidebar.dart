import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class ChannelsSidebar extends ConsumerStatefulWidget {
  final Channel currentChannel;
  final void Function(Channel) onSelectChannel;
  final VoidCallback onClose;

  const ChannelsSidebar({
    super.key,
    required this.currentChannel,
    required this.onSelectChannel,
    required this.onClose,
  });

  @override
  ConsumerState<ChannelsSidebar> createState() => _ChannelsSidebarState();
}

class _ChannelsSidebarState extends ConsumerState<ChannelsSidebar> with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final groups = ref.watch(channelsByGroupProvider);
    final groupNames = groups.keys.toList();

    final displayChannels = _selectedGroup != null ? groups[_selectedGroup] ?? [] : channelsAsync.value ?? [];

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: ClipRRect(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(16.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 320.w,
              color: Colors.black.withValues(alpha: 0.8),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildCategoryChips(groupNames),
                  Expanded(child: _buildChannelList(displayChannels)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Icon(Icons.list, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Text(
            'Каналы',
            style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.close, size: 14.sp, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<String> groupNames) {
    return SizedBox(
      height: 32.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: groupNames.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isActive = _selectedGroup == null;
            return _Chip(label: 'Все', isActive: isActive, onTap: () => setState(() => _selectedGroup = null));
          }
          final name = groupNames[index - 1];
          final isActive = _selectedGroup == name;
          return _Chip(
            label: name,
            isActive: isActive,
            onTap: () => setState(() => _selectedGroup = isActive ? null : name),
          );
        },
      ),
    );
  }

  Widget _buildChannelList(List<Channel> channels) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final ch = channels[index];
        final isCurrent = ch.url == widget.currentChannel.url;

        return GestureDetector(
          onTap: () {
            widget.onSelectChannel(ch);
            widget.onClose();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 2.h),
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
              border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    width: 44.w,
                    height: 28.h,
                    color: Colors.white.withValues(alpha: 0.1),
                    child: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
                        ? Image.network(
                            ch.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => _chPlaceholder(),
                          )
                        : _chPlaceholder(),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch.name,
                        style: TextStyle(fontSize: 12.sp, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ch.groupTitle ?? '',
                        style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.2)),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chPlaceholder() => Center(
    child: Icon(Icons.tv, size: 14.sp, color: Colors.white.withValues(alpha: 0.2)),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}
