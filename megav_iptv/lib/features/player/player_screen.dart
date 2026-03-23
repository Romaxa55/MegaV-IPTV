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
import 'widgets/channels_sidebar.dart';
import 'widgets/epg_overlay.dart';
import 'widgets/info_overlay.dart';
import 'widgets/player_bottom_info.dart';
import 'widgets/player_overlay.dart';
import 'widgets/similar_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerManager _playerManager;
  late final FocusNode _playerFocusNode;
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
    _playerFocusNode = FocusNode(debugLabel: 'PlayerScreen');
    _playerManager = ref.read(playerManagerProvider);
    _init();
  }

  Future<void> _init() async {
    await _playerManager.initialize();
    final channel = ref.read(currentChannelProvider);
    if (channel != null) await _openChannel(channel);
    _resetHideTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playerFocusNode.requestFocus();
    });
  }

  Future<void> _openChannel(Channel channel) async {
    final config = ref.read(decoderConfigProvider);

    String streamUrl = channel.streamUrl;
    if (streamUrl.isEmpty) {
      final api = ref.read(apiClientProvider);
      final url = await api.getBestStreamUrl(channel.id);
      if (url == null || url.isEmpty) return;
      streamUrl = url;
    }

    if (config.usesMedia3) {
      if (!mounted) return;
      _openedViaMedia3 = true;
      _playerManager.media3Engine?.openChannel(context: context, channel: channel, streamUrl: streamUrl);
    } else {
      _openedViaMedia3 = false;
      final isAlreadyPlaying =
          _playerManager.currentUrl == streamUrl &&
          (_playerManager.activeEngine?.currentState == PlayerState.playing ||
              _playerManager.activeEngine?.currentState == PlayerState.loading);

      if (!isAlreadyPlaying) {
        await _playerManager.playChannel(streamUrl, channelId: channel.id.toString());
      }
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
    // If a switch is already pending, use the previewed channel as the base
    final channel = _switchPreview ?? ref.read(currentChannelProvider);
    if (channel == null) return;

    final api = ref.read(apiClientProvider);
    final group = channel.groupTitle;

    try {
      // Fetch channels of the same group to find next/prev correctly
      final result = await api.getChannels(category: group, limit: 1000, offset: 0);
      final channels = result.channels;
      if (channels.isEmpty) return;

      final currentIndex = channels.indexWhere((c) => c.id == channel.id);

      int nextIdx;
      if (currentIndex == -1) {
        nextIdx = 0;
      } else {
        nextIdx = currentIndex + delta;
        if (nextIdx < 0) {
          nextIdx = channels.length - 1; // loop around
        } else if (nextIdx >= channels.length) {
          nextIdx = 0; // loop around
        }
      }

      final next = channels[nextIdx];
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
    _playerFocusNode.dispose();
    if (!_openedViaMedia3) {
      _playerManager.stop();
    }
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
      body: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
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
              if (_playerManager.activeEngine != null)
                _playerManager.activeEngine!.buildVideoWidget(fit: BoxFit.contain),

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

              // Controls overlay
              if (_showControls && channel != null)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: PlayerControlsOverlay(
                    onBack: () => context.pop(),
                    activeOverlay: _overlay,
                    onToggleOverlay: _toggleOverlay,
                  ),
                ),

              // Bottom Info (Hero OSD) — [Positioned] must sit directly under [Stack].
              if ((_showControls || _showBriefOSD || _switchPreview != null) &&
                  _overlay == PlayerOverlayMode.none &&
                  (_switchPreview ?? channel) != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: PlayerBottomInfo(channel: (_switchPreview ?? channel)!, isSwitching: _switchPreview != null),
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _resetHideTimer();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        if (_overlay != PlayerOverlayMode.none) {
          setState(() => _overlay = PlayerOverlayMode.none);
          return KeyEventResult.handled;
        } else {
          return KeyEventResult.ignored; // Let the system back button pop the screen
        }
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.channelUp:
      case LogicalKeyboardKey.pageUp:
      case LogicalKeyboardKey.mediaTrackPrevious:
        if (_overlay == PlayerOverlayMode.none) {
          _quickSwitch(-1);
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.channelDown:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.mediaTrackNext:
        if (_overlay == PlayerOverlayMode.none) {
          _quickSwitch(1);
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        if (_overlay == PlayerOverlayMode.none) {
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.mediaPlayPause:
      case LogicalKeyboardKey.mediaPlay:
      case LogicalKeyboardKey.mediaPause:
        _resetHideTimer();
        if (_overlay == PlayerOverlayMode.none && !_showControls) {
          setState(() => _showControls = true);
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.keyE:
        _toggleOverlay(PlayerOverlayMode.epg);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyI:
        _toggleOverlay(PlayerOverlayMode.info);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyL:
        _toggleOverlay(PlayerOverlayMode.channels);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyR:
        _toggleOverlay(PlayerOverlayMode.similar);
        return KeyEventResult.handled;
      default:
        break;
    }
    return KeyEventResult.ignored;
  }
}
