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

  final _channels = <Channel>[];
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
    _scrollController.addListener(_onScroll);
    _loadChannels(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200.h) {
      _loadChannels();
    }
  }

  Future<void> _loadChannels({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;
    _loading = true;

    if (reset) {
      _channels.clear();
      _hasMore = true;
    }

    final repo = ref.read(playlistRepositoryProvider);
    final group = _selectedGroup;

    List<Channel> batch;
    if (group != null) {
      batch = await repo.getChannelsByGroup(group, limit: _pageSize, offset: _channels.length);
    } else {
      batch = await repo.getChannelsByGroup(_channels.isEmpty ? '' : '', limit: _pageSize, offset: _channels.length);
      // For "all" mode, use search or sequential loading
      batch = await _loadAllChannelsBatch(_channels.length);
    }

    if (mounted) {
      setState(() {
        _channels.addAll(batch);
        _hasMore = batch.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<List<Channel>> _loadAllChannelsBatch(int offset) async {
    final repo = ref.read(playlistRepositoryProvider);
    final db = repo.database;
    final dbInst = await db.database;
    final rows = await dbInst.query('channels', limit: _pageSize, offset: offset, orderBy: 'id ASC');
    return rows
        .map(
          (r) => Channel(
            name: r['name'] as String,
            url: r['url'] as String,
            logoUrl: r['logo_url'] as String?,
            groupTitle: r['group_title'] as String?,
            tvgId: r['tvg_id'] as String?,
            tvgName: r['tvg_name'] as String?,
            language: r['language'] as String?,
          ),
        )
        .toList();
  }

  void _switchGroup(String? group) {
    setState(() => _selectedGroup = group);
    _loadChannels(reset: true);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final groupNames = groupsAsync.value?.map((g) => g.name).toList() ?? [];

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
                  Expanded(child: _buildChannelList()),
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
            return _Chip(label: 'Все', isActive: isActive, onTap: () => _switchGroup(null));
          }
          final name = groupNames[index - 1];
          final isActive = _selectedGroup == name;
          return _Chip(label: name, isActive: isActive, onTap: () => _switchGroup(isActive ? null : name));
        },
      ),
    );
  }

  Widget _buildChannelList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _channels.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _channels.length) {
          return Padding(
            padding: EdgeInsets.all(16.w),
            child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
          );
        }

        final ch = _channels[index];
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
