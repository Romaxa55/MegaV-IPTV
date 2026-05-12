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
import 'cinematic/cinematic_controls_layer.dart';
import 'widgets/channels_sidebar.dart';
import 'widgets/epg_overlay.dart';
import 'widgets/info_overlay.dart';
import 'widgets/player_bottom_info.dart';
import 'widgets/player_overlay.dart';
import 'widgets/similar_overlay.dart';

/// Единый источник истины для видимости UI поверх видео в `PlayerScreen`.
///
/// Sealed-class даёт compile-time exhaustiveness в `switch` и невозможность
/// представить невалидную комбинацию (Req 1.5).
sealed class PlayerUiState {
  const PlayerUiState();
}

/// UI скрыт, видно только видео.
final class HiddenState extends PlayerUiState {
  const HiddenState();
}

/// Полные controls overlay'и (back-button, OSD bar). Авто-скрытие через 4с.
final class ControlsState extends PlayerUiState {
  /// Когда таймер expiry должен сработать.
  final DateTime hideAt;
  const ControlsState({required this.hideAt});
}

/// Краткий OSD при открытии канала или quick-switch commit. Авто-скрытие через 3с.
final class BriefOsdState extends PlayerUiState {
  final DateTime hideAt;
  const BriefOsdState({required this.hideAt});
}

/// Preview следующего/предыдущего канала перед фактическим переключением.
/// Через 1.5с фиксируется как текущий канал.
final class SwitchPreviewState extends PlayerUiState {
  final Channel previewChannel;
  final DateTime commitAt;
  const SwitchPreviewState({required this.previewChannel, required this.commitAt});
}

/// Полный модальный overlay (EPG, Channels, Info, Similar). Без авто-скрытия.
final class OverlayState extends PlayerUiState {
  final PlayerOverlayMode mode;
  const OverlayState({required this.mode});
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerManager _playerManager;
  late final FocusNode _playerFocusNode;

  /// Focus seams for cinematic render tree (Task 3.1, Task 3.4).
  /// These do NOT alter `PlayerUiState` — they live alongside the closed
  /// state machine and only describe where D-pad focus lands within
  /// `ControlsState()`'s render tree.
  late final FocusNode _topBarFocus;
  late final FocusScopeNode _actionFocusScope;
  late final FocusScopeNode _channelDeckFocus;

  bool _openedViaMedia3 = false;

  /// Единый источник истины для видимости UI поверх видео (Req 1.1, 1.3).
  PlayerUiState _uiState = const HiddenState();

  /// Один таймер expiry для всех state-вариантов с auto-hide (Req 2.1).
  /// Заменяет _hideTimer/_osdTimer/_switchTimer.
  Timer? _stateExpiryTimer;

  /// Гард на повторный вход в _quickSwitch до завершения предыдущего вызова
  /// (Req 3.5).
  bool _quickSwitchInFlight = false;

  // ---- Internal state-machine API (Req 3.1, 3.2, 6.1) ----

  /// Test-only entry point для детерминированной проверки переходов
  /// без манипуляции с реальными `Timer`'ами (Req 6.1).
  @visibleForTesting
  void transitionForTest(PlayerUiState newState) => _transition(newState);

  /// Единственная точка мутации `_uiState` (Req 3.1).
  ///
  /// Атомарно: cancel старого таймера → setState → schedule нового
  /// (для тех вариантов, где есть expiry). Никаких await между
  /// шагами — гарантия Req 3.2.
  void _transition(PlayerUiState newState) {
    _stateExpiryTimer?.cancel();
    _stateExpiryTimer = null;
    if (mounted) {
      setState(() {
        _uiState = newState;
      });
    } else {
      _uiState = newState;
    }

    final expiryMs = switch (newState) {
      HiddenState() => null,
      OverlayState() => null,
      ControlsState s => s.hideAt.difference(DateTime.now()).inMilliseconds,
      BriefOsdState s => s.hideAt.difference(DateTime.now()).inMilliseconds,
      SwitchPreviewState s => s.commitAt.difference(DateTime.now()).inMilliseconds,
    };
    if (expiryMs != null && expiryMs > 0) {
      _stateExpiryTimer = Timer(Duration(milliseconds: expiryMs), _onExpiry);
    } else if (expiryMs != null && expiryMs <= 0) {
      // Expiry уже в прошлом — сработать на следующем microtask.
      Future.microtask(_onExpiry);
    }
  }

  void _onExpiry() {
    if (!mounted) return;
    switch (_uiState) {
      case HiddenState():
      case OverlayState():
        // No-op (у этих вариантов нет expiry).
        break;
      case ControlsState():
      case BriefOsdState():
        _transition(const HiddenState());
      case SwitchPreviewState s:
        _commitSwitchPreview(s.previewChannel);
    }
  }

  Future<void> _commitSwitchPreview(Channel next) async {
    ref.read(currentChannelProvider.notifier).state = next;
    ref.read(currentChannelIndexProvider.notifier).state = 0;
    await _openChannel(next);
    // _openChannel в конце сам перейдёт в BriefOsdState.
  }

  void _toggleOverlayKey(PlayerOverlayMode mode) {
    final s = _uiState;
    if (s is OverlayState && s.mode == mode) {
      _transition(const HiddenState());
    } else {
      _transition(OverlayState(mode: mode));
    }
  }

  void _hideOverlay() => _transition(const HiddenState());

  // ---- Lifecycle ----

  @override
  void initState() {
    super.initState();
    _playerFocusNode = FocusNode(debugLabel: 'PlayerScreen');
    _topBarFocus = FocusNode(debugLabel: 'PlayerScreen.topBar');
    _actionFocusScope = FocusScopeNode(debugLabel: 'PlayerScreen.actionRow');
    _channelDeckFocus = FocusScopeNode(debugLabel: 'PlayerScreen.channelDeck');
    _playerManager = ref.read(playerManagerProvider);
    _init();
  }

  /// Proxy to player engine play/pause. Bound to cinematic action row's
  /// play-pause button. NEVER touches `_uiState` — render tree only.
  void _togglePlayPause() {
    final engine = _playerManager.activeEngine;
    if (engine == null) return;
    if (engine.currentState == PlayerState.playing) {
      engine.pause();
    } else {
      engine.play();
    }
  }

  Future<void> _init() async {
    await _playerManager.initialize();
    final channel = ref.read(currentChannelProvider);
    if (channel != null) await _openChannel(channel);
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
    final hideAt = DateTime.now().add(const Duration(seconds: 3));
    _transition(BriefOsdState(hideAt: hideAt));
  }

  void _quickSwitch(int delta) async {
    if (_quickSwitchInFlight) return;
    _quickSwitchInFlight = true;
    try {
      final base = switch (_uiState) {
        SwitchPreviewState s => s.previewChannel,
        _ => ref.read(currentChannelProvider),
      };
      if (base == null) return;

      final api = ref.read(apiClientProvider);
      final group = base.groupTitle;

      final result = await api.getChannels(category: group, limit: 1000, offset: 0);
      final channels = result.channels;
      if (channels.isEmpty) return;

      final currentIndex = channels.indexWhere((c) => c.id == base.id);
      int nextIdx;
      if (currentIndex == -1) {
        nextIdx = 0;
      } else {
        nextIdx = currentIndex + delta;
        if (nextIdx < 0) {
          nextIdx = channels.length - 1;
        } else if (nextIdx >= channels.length) {
          nextIdx = 0;
        }
      }
      final next = channels[nextIdx];
      final commitAt = DateTime.now().add(const Duration(milliseconds: 1500));
      _transition(SwitchPreviewState(previewChannel: next, commitAt: commitAt));
    } catch (_) {
      // existing error swallowing
    } finally {
      _quickSwitchInFlight = false;
    }
  }

  @override
  void dispose() {
    _stateExpiryTimer?.cancel();
    _playerFocusNode.dispose();
    _topBarFocus.dispose();
    _actionFocusScope.dispose();
    _channelDeckFocus.dispose();
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
              CircularProgressIndicator(color: AppColors.primary),
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
            if (_uiState is OverlayState) {
              _transition(const HiddenState());
            } else {
              final hideAt = DateTime.now().add(const Duration(seconds: 4));
              _transition(ControlsState(hideAt: hideAt));
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_playerManager.activeEngine != null)
                _playerManager.activeEngine!.buildVideoWidget(fit: BoxFit.contain),

              const _LoadingErrorIndicator(),

              ..._buildOverlayLayer(channel),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverlayLayer(Channel? channel) {
    if (channel == null) return const [];
    return switch (_uiState) {
      HiddenState() => const [],
      ControlsState() => buildCinematicControlsLayer(
        channel: channel,
        topBarFocus: _topBarFocus,
        actionFocusScope: _actionFocusScope,
        channelDeckFocus: _channelDeckFocus,
        onBack: () => context.pop(),
        onPlayPause: _togglePlayPause,
        onAudio: () => _toggleOverlayKey(PlayerOverlayMode.info),
        onSubs: () => _toggleOverlayKey(PlayerOverlayMode.info),
        onInfo: () => _toggleOverlayKey(PlayerOverlayMode.info),
        onChannelSelected: (ch) => _selectChannel(ch, 0),
      ),
      BriefOsdState() => [
        Positioned(left: 0, right: 0, bottom: 0, child: PlayerBottomInfo(channel: channel, isSwitching: false)),
      ],
      SwitchPreviewState s => [
        Positioned(left: 0, right: 0, bottom: 0, child: PlayerBottomInfo(channel: s.previewChannel, isSwitching: true)),
      ],
      OverlayState s => [_buildModalOverlay(s.mode, channel)],
    };
  }

  Widget _buildModalOverlay(PlayerOverlayMode mode, Channel channel) {
    return switch (mode) {
      PlayerOverlayMode.epg => EpgOverlay(channelName: channel.name, channelId: channel.id, onClose: _hideOverlay),
      PlayerOverlayMode.channels => ChannelsSidebar(
        currentChannel: channel,
        onSelectChannel: (ch) => _selectChannel(ch, 0),
        onClose: _hideOverlay,
      ),
      PlayerOverlayMode.info => InfoOverlay(channel: channel, onClose: _hideOverlay),
      PlayerOverlayMode.similar => SimilarOverlay(
        currentChannel: channel,
        onSelectChannel: (ch) => _selectChannel(ch, 0),
        onClose: _hideOverlay,
      ),
      PlayerOverlayMode.none => const SizedBox.shrink(),
    };
  }

  void _selectChannel(Channel ch, int indexInGroup) {
    ref.read(currentChannelProvider.notifier).state = ch;
    ref.read(currentChannelIndexProvider.notifier).state = indexInGroup;
    _openChannel(ch);
    _transition(const HiddenState());
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ESC / goBack: close overlay if open, else let system handle.
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_uiState is OverlayState) {
        _transition(const HiddenState());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Channel up family.
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (_uiState is HiddenState || _uiState is ControlsState) {
        _quickSwitch(-1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Channel down family.
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      if (_uiState is HiddenState || _uiState is ControlsState) {
        _quickSwitch(1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Arrow left/right: absorb when no overlay (existing behavior).
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      if (_uiState is HiddenState || _uiState is ControlsState) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Select / Enter / Play family — show controls (or re-arm).
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (_uiState is HiddenState || _uiState is ControlsState) {
        final hideAt = DateTime.now().add(const Duration(seconds: 4));
        _transition(ControlsState(hideAt: hideAt));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Overlay toggle keys.
    if (key == LogicalKeyboardKey.keyE) {
      _toggleOverlayKey(PlayerOverlayMode.epg);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyI) {
      _toggleOverlayKey(PlayerOverlayMode.info);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _toggleOverlayKey(PlayerOverlayMode.channels);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _toggleOverlayKey(PlayerOverlayMode.similar);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}

/// Изолированная подписка на `_playerManager.stateStream`.
///
/// Wrapped в `RepaintBoundary`, чтобы тики stream'а не вызывали ребилд
/// родительского `Stack` плеера и не инвалидировали покраску видео-текстуры
/// либо overlay-слоёв (Req 5.1, 5.2, 5.3).
class _LoadingErrorIndicator extends ConsumerWidget {
  const _LoadingErrorIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(playerManagerProvider);
    return RepaintBoundary(
      child: StreamBuilder<PlayerState>(
        stream: manager.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? PlayerState.idle;
          if (state == PlayerState.loading) {
            // player-cinematic-redux follow-up: «загрузка» — мягкий
            // спиннер + подпись, чтобы юзер понимал что идёт
            // соединение/восстановление (а не просто крутится без
            // объяснения). PlayerManager сейчас входит в state=loading
            // каждый раз когда retry-backoff делает .open(), так что
            // эта же ветка покрывает и initial play, и reconnect.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 14.h),
                  Text(
                    'Подключение…',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15.sp),
                  ),
                ],
              ),
            );
          }
          if (state == PlayerState.error) {
            // Error отображается между attempts (~1-60 сек backoff).
            // Текст явно говорит что ретрай идёт автоматически, чтобы
            // юзер не паниковал и не перезапускал канал руками.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.signal_wifi_statusbar_connected_no_internet_4, color: AppColors.error, size: 48.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'Восстанавливаю соединение…',
                    style: TextStyle(color: AppColors.error, fontSize: 16.sp, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Канал автоматически продолжит, когда сеть вернётся',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.sp),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
