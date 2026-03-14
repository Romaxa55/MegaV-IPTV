import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_engine.dart';
import '../../core/player/player_manager.dart';
import '../../core/playlist/models/channel.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/player_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerManager _playerManager;
  bool _showOverlay = true;
  Timer? _overlayTimer;
  bool _openedViaMedia3 = false;

  @override
  void initState() {
    super.initState();
    _playerManager = ref.read(playerManagerProvider);
    _init();
  }

  Future<void> _init() async {
    await _playerManager.initialize();

    final channel = ref.read(currentChannelProvider);
    if (channel != null) {
      await _openChannel(channel);
    }

    _startOverlayTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _openChannel(Channel channel) async {
    final config = ref.read(decoderConfigProvider);

    if (config.usesMedia3) {
      _openedViaMedia3 = true;
      final channels = ref.read(filteredChannelsProvider);
      final index = ref.read(currentChannelIndexProvider);
      channels.whenData((list) {
        _playerManager.media3Engine?.openChannel(
          context: context,
          channel: channel,
          playlist: list,
          initialIndex: index >= 0 ? index : 0,
        );
      });
    } else {
      _openedViaMedia3 = false;
      await _playerManager.playChannel(
        channel.url,
        channelId: channel.tvgId ?? channel.name,
      );
    }
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) _startOverlayTimer();
  }

  Future<void> _switchChannel(int delta) async {
    final channels = ref.read(filteredChannelsProvider);
    final currentIndex = ref.read(currentChannelIndexProvider);

    channels.whenData((list) async {
      final newIndex = (currentIndex + delta).clamp(0, list.length - 1);
      if (newIndex != currentIndex) {
        ref.read(currentChannelIndexProvider.notifier).state = newIndex;
        ref.read(currentChannelProvider.notifier).state = list[newIndex];
        await _openChannel(list[newIndex]);
        setState(() => _showOverlay = true);
        _startOverlayTimer();
      }
    });
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _playerManager.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(currentChannelProvider);

    if (_openedViaMedia3) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16.h),
              Text(
                'Playing in System player...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _toggleOverlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_playerManager.mediaKitEngine != null)
                _playerManager.mediaKitEngine!.buildVideoWidget(
                  fit: BoxFit.contain,
                ),
              StreamBuilder<PlayerState>(
                stream: _playerManager.stateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? PlayerState.idle;
                  if (state == PlayerState.loading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (state == PlayerState.error) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: AppColors.error, size: 48.sp),
                          SizedBox(height: 12.h),
                          Text(
                            'Playback error. Retrying...',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (_showOverlay && channel != null)
                PlayerOverlay(
                  channelName: channel.name,
                  groupName: channel.groupTitle,
                  onBack: () => context.pop(),
                  onChannelUp: () => _switchChannel(-1),
                  onChannelDown: () => _switchChannel(1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.channelUp:
        _switchChannel(-1);
        break;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.channelDown:
        _switchChannel(1);
        break;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _toggleOverlay();
        break;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        context.pop();
        break;
      default:
        if (!_showOverlay) {
          setState(() => _showOverlay = true);
          _startOverlayTimer();
        }
    }
  }
}
