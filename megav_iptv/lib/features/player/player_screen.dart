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
import 'widgets/channel_switch_osd.dart';
import 'widgets/channels_sidebar.dart';
import 'widgets/epg_overlay.dart';
import 'widgets/info_overlay.dart';
import 'widgets/player_overlay.dart';
import 'widgets/similar_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerManager _playerManager;
  bool _showControls = true;
  PlayerOverlayMode _overlay = PlayerOverlayMode.none;
  Timer? _hideTimer;
  bool _openedViaMedia3 = false;

  Channel? _switchPreview;
  Timer? _switchTimer;

  bool _showBriefOSD = false;
  Timer? _osdTimer;

  @override
  void initState() {
    super.initState();
    _playerManager = ref.read(playerManagerProvider);
    _init();
  }

  Future<void> _init() async {
    await _playerManager.initialize();
    final channel = ref.read(currentChannelProvider);
    if (channel != null) await _openChannel(channel);
    _resetHideTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _openChannel(Channel channel) async {
    final config = ref.read(decoderConfigProvider);

    if (config.usesMedia3) {
      _openedViaMedia3 = true;
      _playerManager.media3Engine?.openChannel(
        context: context,
        channel: channel,
        playlist: [channel],
        initialIndex: 0,
      );
    } else {
      _openedViaMedia3 = false;
      await _playerManager.playChannel(channel.url, channelId: channel.id);
    }
    _showBriefOSDFor();
  }

  void _resetHideTimer() {
    setState(() => _showControls = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _overlay == PlayerOverlayMode.none) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showBriefOSDFor() {
    setState(() => _showBriefOSD = true);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBriefOSD = false);
    });
  }

  void _toggleOverlay(PlayerOverlayMode mode) {
    setState(() {
      _overlay = _overlay == mode ? PlayerOverlayMode.none : mode;
    });
    _resetHideTimer();
  }

  void _quickSwitch(int delta) async {
    final currentIndex = ref.read(currentChannelIndexProvider);
    final group = ref.read(selectedGroupProvider);
    final api = ref.read(apiClientProvider);

    // TODO: Need total count from backend. For now just try to load next.
    final nextIdx = currentIndex + delta;
    if (nextIdx < 0) return;

    try {
      final channels = await api.getChannels(group: group, limit: 1, offset: nextIdx);
      if (channels.isEmpty) return;

      final next = channels.first;
      setState(() => _switchPreview = next);

      _switchTimer?.cancel();
      _switchTimer = Timer(const Duration(milliseconds: 1500), () async {
        ref.read(currentChannelIndexProvider.notifier).state = nextIdx;
        ref.read(currentChannelProvider.notifier).state = next;
        await _openChannel(next);
        if (mounted) setState(() => _switchPreview = null);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _switchTimer?.cancel();
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
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Back')),
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
          onTap: () {
            if (_overlay != PlayerOverlayMode.none) {
              setState(() => _overlay = PlayerOverlayMode.none);
            } else {
              _resetHideTimer();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_playerManager.mediaKitEngine != null)
                _playerManager.mediaKitEngine!.buildVideoWidget(fit: BoxFit.contain),

              StreamBuilder<PlayerState>(
                stream: _playerManager.stateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? PlayerState.idle;
                  if (state == PlayerState.loading) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (state == PlayerState.error) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 48.sp),
                          SizedBox(height: 12.h),
                          Text(
                            'Playback error. Retrying...',
                            style: TextStyle(color: AppColors.error, fontSize: 16.sp),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Channel switch preview OSD
              if (_switchPreview != null) ChannelSwitchPreview(channel: _switchPreview!),

              // Brief OSD
              if (_showBriefOSD &&
                  !_showControls &&
                  _overlay == PlayerOverlayMode.none &&
                  _switchPreview == null &&
                  channel != null)
                BriefChannelOSD(channel: channel),

              // Controls overlay
              if (_showControls && channel != null)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: PlayerControlsOverlay(
                    channelName: channel.name,
                    groupName: channel.groupTitle,
                    channelId: channel.id,
                    logoUrl: channel.logoUrl,
                    onBack: () => context.pop(),
                    onChannelUp: () => _quickSwitch(1),
                    onChannelDown: () => _quickSwitch(-1),
                    activeOverlay: _overlay,
                    onToggleOverlay: _toggleOverlay,
                  ),
                ),

              // EPG overlay
              if (_overlay == PlayerOverlayMode.epg && channel != null)
                EpgOverlay(
                  channelName: channel.name,
                  channelId: channel.id,
                  onClose: () => setState(() => _overlay = PlayerOverlayMode.none),
                ),

              // Channels sidebar
              if (_overlay == PlayerOverlayMode.channels && channel != null)
                ChannelsSidebar(
                  currentChannel: channel,
                  onSelectChannel: (ch) => _selectChannel(ch, 0),
                  onClose: () => setState(() => _overlay = PlayerOverlayMode.none),
                ),

              // Info overlay
              if (_overlay == PlayerOverlayMode.info && channel != null)
                InfoOverlay(channel: channel, onClose: () => setState(() => _overlay = PlayerOverlayMode.none)),

              // Similar overlay
              if (_overlay == PlayerOverlayMode.similar && channel != null)
                SimilarOverlay(
                  currentChannel: channel,
                  onSelectChannel: (ch) => _selectChannel(ch, 0),
                  onClose: () => setState(() => _overlay = PlayerOverlayMode.none),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectChannel(Channel ch, int indexInGroup) {
    ref.read(currentChannelProvider.notifier).state = ch;
    ref.read(currentChannelIndexProvider.notifier).state = indexInGroup;
    _openChannel(ch);
    setState(() => _overlay = PlayerOverlayMode.none);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _resetHideTimer();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        if (_overlay != PlayerOverlayMode.none) {
          setState(() => _overlay = PlayerOverlayMode.none);
        } else {
          context.pop();
        }
      case LogicalKeyboardKey.arrowUp:
        if (_overlay == PlayerOverlayMode.none) _quickSwitch(-1);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.channelDown:
        if (_overlay == PlayerOverlayMode.none) _quickSwitch(1);
      case LogicalKeyboardKey.channelUp:
        if (_overlay == PlayerOverlayMode.none) _quickSwitch(-1);
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _resetHideTimer();
      case LogicalKeyboardKey.keyE:
        _toggleOverlay(PlayerOverlayMode.epg);
      case LogicalKeyboardKey.keyI:
        _toggleOverlay(PlayerOverlayMode.info);
      case LogicalKeyboardKey.keyL:
        _toggleOverlay(PlayerOverlayMode.channels);
      case LogicalKeyboardKey.keyR:
        _toggleOverlay(PlayerOverlayMode.similar);
      default:
        break;
    }
  }
}
