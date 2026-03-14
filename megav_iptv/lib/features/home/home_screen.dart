import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/playlist/models/channel.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/content_row.dart';
import 'widgets/hero_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _focusedRow = -1; // -1 = hero
  int _focusedCol = 0;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _openChannel(Channel channel, int indexInGroup) {
    ref.read(currentChannelProvider.notifier).state = channel;
    ref.read(currentChannelIndexProvider.notifier).state = indexInGroup;
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistLoadProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final featuredAsync = ref.watch(featuredChannelsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: playlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
              SizedBox(height: 16.h),
              Text(
                'Error: $error',
                style: TextStyle(fontSize: 14.sp, color: AppColors.error),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(onPressed: () => ref.invalidate(playlistLoadProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (_) {
          final featured = featuredAsync.value ?? [];
          final groups = groupsAsync.value ?? [];

          return KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (event) => _handleKeyEvent(event, groups),
            child: Column(
              children: [
                HeroSection(featuredChannels: featured, onPlay: (ch) => _openChannel(ch, 0)),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: 32.h),
                    itemCount: groups.length,
                    itemBuilder: (context, rowIdx) {
                      final group = groups[rowIdx];
                      return _LazyContentRow(
                        groupName: group.name,
                        channelCount: group.count,
                        isFocusedRow: _focusedRow == rowIdx,
                        focusedCol: _focusedRow == rowIdx ? _focusedCol : -1,
                        onChannelTap: _openChannel,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, List<({String name, int count})> groups) {
    if (event is! KeyDownEvent) return;

    setState(() {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (_focusedRow <= 0) {
            _focusedRow = -1;
          } else {
            _focusedRow--;
          }
        case LogicalKeyboardKey.arrowDown:
          if (_focusedRow == -1) {
            _focusedRow = 0;
            _focusedCol = 0;
          } else if (_focusedRow < groups.length - 1) {
            _focusedRow++;
          }
        case LogicalKeyboardKey.arrowLeft:
          if (_focusedRow >= 0) {
            _focusedCol = (_focusedCol - 1).clamp(0, 999);
          }
        case LogicalKeyboardKey.arrowRight:
          if (_focusedRow >= 0 && _focusedRow < groups.length) {
            final maxCol = (groups[_focusedRow].count) - 1;
            _focusedCol = (_focusedCol + 1).clamp(0, maxCol);
          }
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.select:
          // Handled by ContentRow tap
          break;
        default:
          break;
      }
    });
  }
}

/// A ContentRow that lazily loads its channels from DB.
class _LazyContentRow extends ConsumerStatefulWidget {
  final String groupName;
  final int channelCount;
  final bool isFocusedRow;
  final int focusedCol;
  final void Function(Channel channel, int index) onChannelTap;

  const _LazyContentRow({
    required this.groupName,
    required this.channelCount,
    this.isFocusedRow = false,
    this.focusedCol = -1,
    required this.onChannelTap,
  });

  @override
  ConsumerState<_LazyContentRow> createState() => _LazyContentRowState();
}

class _LazyContentRowState extends ConsumerState<_LazyContentRow> {
  static const _pageSize = 20;
  final List<Channel> _channels = [];
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;

    final repo = ref.read(playlistRepositoryProvider);
    final batch = await repo.getChannelsByGroup(widget.groupName, limit: _pageSize, offset: _channels.length);

    if (mounted) {
      setState(() {
        _channels.addAll(batch);
        _hasMore = batch.length == _pageSize;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentRow(
      title: widget.groupName,
      channels: _channels,
      totalCount: widget.channelCount,
      isFocusedRow: widget.isFocusedRow,
      focusedCol: widget.focusedCol,
      onChannelTap: widget.onChannelTap,
      onLoadMore: _hasMore ? _loadMore : null,
    );
  }
}
