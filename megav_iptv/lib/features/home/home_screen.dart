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
    final allChannels = ref.read(channelsProvider).value ?? [];
    final globalIndex = allChannels.indexOf(channel);
    ref.read(currentChannelProvider.notifier).state = channel;
    ref.read(currentChannelIndexProvider.notifier).state = globalIndex >= 0 ? globalIndex : 0;
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final featured = ref.watch(featuredChannelsProvider);
    final groups = ref.watch(channelsByGroupProvider);
    final groupNames = groups.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: channelsAsync.when(
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
              ElevatedButton(onPressed: () => ref.invalidate(channelsProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (_) => KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) => _handleKeyEvent(event, groupNames, groups),
          child: Column(
            children: [
              HeroSection(featuredChannels: featured, onPlay: (ch) => _openChannel(ch, 0)),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 32.h),
                  itemCount: groupNames.length,
                  itemBuilder: (context, rowIdx) {
                    final name = groupNames[rowIdx];
                    final channels = groups[name]!;
                    return ContentRow(
                      title: name,
                      channels: channels,
                      isFocusedRow: _focusedRow == rowIdx,
                      focusedCol: _focusedRow == rowIdx ? _focusedCol : -1,
                      onChannelTap: _openChannel,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, List<String> groupNames, Map<String, List<Channel>> groups) {
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
          } else if (_focusedRow < groupNames.length - 1) {
            _focusedRow++;
          }
        case LogicalKeyboardKey.arrowLeft:
          if (_focusedRow >= 0) {
            _focusedCol = (_focusedCol - 1).clamp(0, 999);
          }
        case LogicalKeyboardKey.arrowRight:
          if (_focusedRow >= 0) {
            final name = groupNames[_focusedRow];
            final maxCol = (groups[name]?.length ?? 1) - 1;
            _focusedCol = (_focusedCol + 1).clamp(0, maxCol);
          }
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.select:
          if (_focusedRow >= 0) {
            final name = groupNames[_focusedRow];
            final channels = groups[name]!;
            final col = _focusedCol.clamp(0, channels.length - 1);
            _openChannel(channels[col], col);
          } else if (ref.read(featuredChannelsProvider).isNotEmpty) {
            _openChannel(ref.read(featuredChannelsProvider).first, 0);
          }
        default:
          break;
      }
    });
  }
}
